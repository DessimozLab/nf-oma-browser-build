#!/usr/bin/env python

import sys
import pickle as pkl
import os
import itertools
from collections import defaultdict
import csv
import gzip

mode = "with_family"


def rangesAsList(i, merge_small_gaps=False):
    x=[]
    for start,stop in ranges(i):
        x.append([start, stop])
     
    return x

def getRegionsAsString(regions):

    a=[]
    for start_stop in regions:
        a.append("-".join(map(str,start_stop)))
    return ",".join(a)


def ranges(i):
    for a, b in itertools.groupby(enumerate(i), lambda tup: tup[1] - tup[0]):
        b = list(b)
        yield b[0][1], b[-1][1]


def load_discontinuous_regs(fpath):
    open_ = gzip.open if fpath.endswith(".gz") else open
    with open_(fpath, 'rb') as fh:
        discontinuous_regs = pkl.load(fh)
    return discontinuous_regs


def load_domain_to_superfamily(fpath):
    dom_to_fam={}
    open_ = gzip.open if fpath.endswith(".gz") else open
    with open_(fpath, 'rt') as ifh:
        for line in ifh:
            line = line.replace("\n","")
            if line.startswith("#"):
                continue
            vals = line.split()
            superfamily= ".".join(vals[1:5])
            domain_id =vals[0]
            dom_to_fam[domain_id] = superfamily
    return dom_to_fam


def process_cath_resolve_hits_file(infile, outfile, evalue_coff, dom_to_fam, discontinuous_regs):
    """open cath resolve hits file, add a CATH superfamily column and split up discontinous HMM's into component domains"""
    open_ = gzip.open if infile.endswith(".gz") else open
    with open_(infile) as ifh, open_(outfile, "w") as of:
        ofh = csv.writer(of)

        for line in ifh:
            line = line.rstrip()
            vals =line.split()
            
            if line.startswith("#"):
                if line.startswith("#FIELD"):
                    ofh.writerow(["#domain_id","cath-superfamily"] + vals[1:]) 
                continue   
            
            hmm_id = vals[1] 
            if hmm_id.startswith("dc_") is False: 
                dom = hmm_id.split("-")[0]
                sfam = dom_to_fam.get(dom, "")
                
                if mode == "with_family": 
                    if len(sfam)==0: 
                        continue
                    evalue = float(vals[-1])
                    if evalue > evalue_coff: 
                        continue
                
                ofh.writerow([dom,sfam] + vals + [""])
                continue
            
            # process discontinuous HMM's
            sequence_id, hmm_id, bit_score, start_stop, final_start_stop, alignment_regs,cond_eval, ind_eval = vals

            final_start_stop_list=[]
            for i in final_start_stop.split(","):
                final_start_stop_list.append(map(int,i.split("-")))
            try:
                plup = discontinuous_regs[hmm_id]
            except KeyError:
                print(f"Warning: could not find discontinuous regions for {hmm_id}", file=sys.stderr)
                continue
            
            mda_resolved_aas = set()
            for start,stop in final_start_stop_list:
                mda_resolved_aas |= set(range(start, stop +1))

            dom_sequence_regs = defaultdict(list)
            resi_dom={}
            for areg in alignment_regs.split(";"):
                hmm_region, seq_region = areg.split(",") 
                hmm_start, hmm_stop =map(int, hmm_region.split("-"))
                seq_start, seq_stop =map(int, seq_region.split("-"))
                seq_pos = range(seq_start, seq_stop +1)
                    
                for c,i in enumerate(range(hmm_start, hmm_stop+1)):
                    
                    dom, resi, ostat = plup.get(i-1, [None,None,None]) #zero indexed 
                    aa_num = seq_pos[c]
                    if aa_num not in mda_resolved_aas: continue
                    
                    resi_dom[seq_pos[c]]=[dom,ostat]
                    if dom: 
                        dom_sequence_regs[dom].append(seq_pos[c])
            #fill 
            for dom, regs in dom_sequence_regs.items():
                
                sequence_regs = rangesAsList(regs)
                new_sequence_regs=[]
                for c,reg in enumerate(sequence_regs):
                
                    if c==0:
                        new_sequence_regs.append(reg)
                        continue
                    prev_reg = new_sequence_regs[-1]

                    if reg[0] - prev_reg[1] <=20:
                        conflict = False
                        
                        for resi in range(prev_reg[0]+1, reg[1]):
                            dom2,ostat = resi_dom.get(resi,[None, None])
                            if dom2 is None: continue
                            if dom2 != dom: 
                                conflict =True
                                break

                        if conflict is False:
                            new_reg = [prev_reg[0], reg[1]]
                            new_sequence_regs[-1]= new_reg    

                        else:new_sequence_regs.append(reg)
                    else:
                        new_sequence_regs.append(reg)
                
                reg_ostats=[]
                for reg in new_sequence_regs:
                    reg_ostat = set([resi_dom[reg[0]][1],  resi_dom[reg[1]][1] ])
                    if len(reg_ostat) > 1: reg_ostat = "*"
                    else:  reg_ostat = "".join(list(reg_ostat))
                    reg_ostats.append(reg_ostat)

                reg_ostats_string = "".join(reg_ostats)
                sequence_regs_string = getRegionsAsString(new_sequence_regs)
                tot_res = 0
                for start,stop in new_sequence_regs:
                    tot_res += (stop - start) +1
                if tot_res < 10: continue
                vals[1] = hmm_id + "_" + dom
                vals[4] =sequence_regs_string

                sfam =  dom_to_fam.get(dom,"")
                if mode =="with_family":   
                    if len(sfam) ==0: continue
                    evalue = float(vals[-1])
                    if evalue > evalue_coff: continue

                ofh.writerow([dom, sfam] +  vals + [reg_ostats_string])

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Add CATH superfamily column to cath resolve hits file")
    parser.add_argument("--infile", required=True, help="CATH resolve hits file")
    parser.add_argument("--out", required=True, help="Output file")
    parser.add_argument("--evalue-coff", type=float, default=0.001, help="E-value cutoff")
    parser.add_argument("--dom-to-fam", required=True, help="cath-domain-list file with Domain to superfamily mapping")
    parser.add_argument("--discontinuous-regs", required=True, help="Discontinuous regions file")
    conf = parser.parse_args()

    dom_to_fam = load_domain_to_superfamily(conf.dom_to_fam)
    discontinuous_regs = load_discontinuous_regs(conf.discontinuous_regs)
    process_cath_resolve_hits_file(conf.infile, conf.out, conf.evalue_coff, dom_to_fam, discontinuous_regs)


if __name__ == '__main__':
    main()