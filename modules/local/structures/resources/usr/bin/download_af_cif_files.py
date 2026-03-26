#!/usr/bin/env python3

import logging
import collections
import io
import os
import threading
import csv
import time
import gzip
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests

thread_local = threading.local()

def get_session(pool_maxsize):
    if not hasattr(thread_local, "session"):
        session = requests.Session()
        adapter = requests.adapters.HTTPAdapter(pool_connections=1, pool_maxsize=pool_maxsize)
        session.mount("https://", adapter)
        thread_local.session = session
    return thread_local.session


# ---------------------------
# Get CIF url for accession
# ---------------------------
def get_cif_url_template(test_acc="P12345"):
    url = f"https://alphafold.ebi.ac.uk/api/prediction/{test_acc}"
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    data = r.json()
    if not data:
        raise ValueError("No data returned")

    entry = data[0]
    cif_url = entry["cifUrl"]
    return make_cif_url_template(cif_url)

def make_cif_url_template(cif_url:str) -> str:
    pattern = r"(.*AF-)([A-Z0-9]+)(-F\d+-model_)(v\d+)(\.cif)"
    match = re.search(pattern, cif_url)
    if not match:
        raise ValueError("URL does not match expected pattern")
    prefix, acc, middle, version. suffix = match.groups()
    template = f"{prefix}{{acc}}{middle}{version}{suffix}"
    return template


# ---------------------------
# Download function
# ---------------------------
def download_one(acc: str, url_template: str, output_dir: Path, timeout: int, max_retries: int , pool_maxsize: int):
    session = get_session()
    url = url_template.format(acc=acc)
    filepath = output_dir / f"{acc}.cif.gz")

    # skip if already exists (important for resume)
    if filepath.exists():
        return (acc, "skipped")

    for attempt in range(max_retries):
        try:
            r = session.get(url, stream=True, timeout=timeout)

            if r.status_code == 200:
                with gzip.open(filepath, "wb") as f:
                    for chunk in r.iter_content(8192):
                        if chunk:
                            f.write(chunk)
                return (acc, "ok")

            elif r.status_code == 404:
                return (acc, "not_found")
        except Exception:
            time.sleep(2 ** attempt)

    return (acc, "failed")



# ---------------------------
# Main function
# ---------------------------
def download_alphafold_requests(accessions, output_dir, summary_file, timeout, max_retries, n_threads, missing_log):
    output_dir = Path(output_dir)
    output_dir.make_dirs(exist_ok=True, parents=True)

    url_template = get_cif_url_template()

    with open(summary_file, "w", newline="") as f, open(missing_log, "w") as missing_f:
        writer = csv.writer(f)
        writer.writerow(["accession", "status"])

        with ThreadPoolExecutor(max_workers=n_threads) as executor:
            futures = {
                executor.submit(
                    download_one, 
                    acc, 
                    url_template,
                    output_dir,
                    timeout,
                    max_retries, n_threads
                ): acc for acc in accessions
            }

            for future in as_completed(futures):
                result = future.result()
                if result[1] != "ok":
                    missing_f.write(result[0] + "\n")
                writer.writerow(result)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Download AlphaFold CIF files")
    parser.add_argument("accessions_file", help="File with list of accessions (one per line)")
    parser.add_argument("--out-cif-folder", default="cif_files", help="Directory to save CIF files")
    parser.add_argument("--out-missing", default="missing_accessions.txt", help="File to log missing accessions")
    parser.add_argument("--summary_file", default="download_summary.csv", help="CSV file to save download summary")
    parser.add_argument("--nr-procs", type=int, default=4, help="Number of parallel processes")
    parser.add_argument("--timeout", type=int, default=30, help="Request timeout in seconds")
    parser.add_argument("--max-retries", type=int, default=3, help="Maximum number of retries for failed downloads")
    conf = parser.parse_args()

    # read accessions
    with gzip.open(conf.accessions_file, rt) as f:
        accessions = [line.strip() for line in f if line.strip()]
    
    download_alphafold_requests(
        accessions=accessions,
        output_dir=conf.out_cif_folder,
        missing_log=conf.out_missing,
        summary_file=conf.summary_file,
        timeout=conf.timeout,
        max_retries=conf.max_retries,
        n_threads=10*conf.nr_procs,
    )


if __name__ == "__main__"
    main()