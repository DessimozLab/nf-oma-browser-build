#!/usr/bin/env python

import gzip
import re

def parse_matrix_file(matrix_file):
    open_ = gzip.open if matrix_file.endswith('.gz') else open
    with open_(matrix_file, 'rt') as fh:
        genomes_re = re.compile(r'^genomes\s*:=\s*\[(?P<genomes>.*)\][:;]\s*$')
        for i, line in enumerate(fh):
            if i > 100:
                raise ValueError("'genomes' line missing from matrix file")
            m = genomes_re.match(line)
            if m is not None:
                genomes = [z.strip() for z in m.group('genomes').split(',')]
                break

        grps = [collections.defaultdict(int) for _ in genomes]
        _m_re = re.compile(r"^_M\[(?P<grp>\d+),(?P<sp>\t+)\]\s*:=\s*(?P<nr>\t+)[:;]$")
        for line in fh:
            m = _m_re.match(line)
            if m is not None:
                sp = int(m.group('sp')) - 1
                nr = int(m.group('nr'))
                grp = int(m.group('grp'))
                grps[sp][nr] = grp
    return {genomes[g]: grps[g] for g in range(len(genomes))}



if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description="Extract the OMA Groups from the Matrix file and store in json format")
    parser.add_argument('--matrix', required=True, help="Matrix file")
    parser.add_argument('--out', required=True, help="Path to output file")
    conf = parser.parse_args()

    with open(conf.out, 'w') as f:
        json.dump(parse_matrix_file(conf.matrix), f)