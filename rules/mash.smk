

rule mash_sketch_genome:
    input:
        genome_folder
    output:
        "mash/genomes.msh"
    params:
        k= config['mash']['k'],
        s= config['mash']['sketch_size'],
        out_name = lambda wc, output: os.path.splitext(output[0])[0]
    threads:
        config['threads']
    conda:
        "../envs/mash.yaml"
    log:
        "logs/mash/sketch.log"
    shell:
        "mash sketch -o {params.out_name} -p {threads} -s {params.s} -k {params.k} {input[0]}/* 2> {log}"


rule mash_calculate_dist:
    input:
        genomes=rules.mash_sketch_genome.output
    output:
        "mash/dists.txt"
    params:
        d= config['mash']['max_dist']
    threads:
        config['threads']
    conda:
        "../envs/mash.yaml"
    log:
        "logs/mash/dist.log"
    shell:
        "mash dist -p {threads} -d {params.d} {input.genomes} {input.genomes} > {output[0]} 2> {log}"



localrules: cluster_mash,get_representatives
checkpoint cluster_mash:
    input:
        dists=rules.mash_calculate_dist.output[0],
        quality ="tables/Genome_quality.tsv",
    output:
        cluster_file="tables/mag2species.tsv",
        scores="tables/evaluation_species_clustering.tsv"
    params:
        treshold=config['species_treshold'],
        linkage_method=config.get('linkage_method','average'),
    script:
        "../scripts/group_species.py"


def get_species(wildcards):
    import pandas as pd
    cluster_file=checkpoints.cluster_mash.get().output.cluster_file

    df= pd.read_csv(cluster_file,sep='\t',index_col=0)
    return list(df.Species.unique())

def get_representative_species(wildcards):
    import pandas as pd
    cluster_file=checkpoints.cluster_mash.get().output.cluster_file

    df= pd.read_csv(cluster_file,sep='\t',index_col=0)
    return list(df.Representative_Species.unique())


checkpoint get_representatives:
    input:
        dir= genome_folder,
        cluster_file= "tables/mag2{taxrank}.tsv"
    output:
        dir= directory("representatives/{taxrank}"),
    run:

        import pandas as pd
        df= pd.read_csv(input.cluster_file,sep='\t')

        rep= "Representative_S"+wildcards.taxrank[1:]

        output_dir = output.dir
        os.makedirs(output_dir)
        input_dir= os.path.relpath(input.dir,start=output_dir)



        for genome in df[rep].unique():
            os.symlink(os.path.join(input_dir,genome+'.fasta'),
                       os.path.join(output_dir,genome+'.fasta')
                   )



rule run_bbsketch:
    input:
        genome_folder= genome_folder,
    output:
        sketch="bbsketch/mags.sketch.gz",
        dists= "tables/bbsketch_dists.tsv"
    threads:
        config['threads']
    conda:
        "../envs/bbmap.yaml"
    resources:
        mem= 50
    log:
        "logs/bbsketch/workflow.log"
    params:
        path= os.path.dirname(workflow.snakefile),
        amino=True
    shell:
        "snakemake -s {params.path}/rules/bbsketch.smk "
        " --reason "
        "--config  "
        " genome_folder='{input.genome_folder}' "
        " sketch={output.sketch} "
        " amino={params.amino} "
        " dists={output.dists} "
        " --rerun-incomplete "
        "-j {threads} --nolock 2> {log}"
