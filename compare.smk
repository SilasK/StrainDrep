#this snakefile is for comparison of a given genome set


snakemake_folder= os.path.dirname(workflow.snakefile)
# use default config
configfile: os.path.join(snakemake_folder,'default_config.yaml')

import os,sys
from glob import glob

genome_folder='genomes'

input_genome_folder=config['genome_folder']



sys.path.append(os.path.join(snakemake_folder,'scripts'))
from common import genome_pdist as gd
from common import io



include: "rules/fastani.smk"
include: "rules/pyani.smk"
include: "rules/bbsketch.smk"

include: "rules/precluster.smk"
include: "rules/alignments.smk"
include: "rules/cluster.smk"

rule all:
    input:
        #"tables/fastANI_dists.tsv",
        #expand("pyani/{method}",method=['ANIm','ANIb']),
        f"tables/{config['strains_based_on']}_dists.tsv",
        "representatives/strains",
        "representatives/species"


rule all_bbsketch:
    input:
        "tables/bbsketch_aa.tsv",
        "tables/bbsketch_nt.tsv",
        "tables/mapping2refseq_aa.sketch.gz"

rule all_species:
    input:
        "tables/refseq_mapping_species.tsv",
        "representatives/species",

rule multik:
    input:
        expand("tables/bindash_dists_K{k}.tsv", k=[13,15,17,19,21,25,29,31,35])


for r in workflow.rules:
    if not "mem" in r.resources:
        r.resources["mem"]=config["mem"]['default']
    if not "time" in r.resources:
        r.resources["time"]=config["runtime"]["default"]

#
