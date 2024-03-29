process Manta {
    container 'quay.io/biocontainers/manta:1.6.0--h9ee0642_1'
    cpus 10
    memory '8GB'

    input:
    tuple path(bams), path(indices)
    path(fasta)
    path(fai)

    script:
    def input_files = bams.collect{"--bam ${it}"}.join(' ')
    """
    configManta.py \\
        ${input_files} \\
        --reference $fasta \\
        --runDir manta

    python manta/runWorkflow.py -m local -j $task.cpus

    mv manta/results/variants/candidateSmallIndels.vcf.gz \\
        example.candidate_small_indels.vcf.gz
    mv manta/results/variants/candidateSmallIndels.vcf.gz.tbi \\
        example.candidate_small_indels.vcf.gz.tbi
    mv manta/results/variants/candidateSV.vcf.gz \\
        example.candidate_sv.vcf.gz
    mv manta/results/variants/candidateSV.vcf.gz.tbi \\
        example.candidate_sv.vcf.gz.tbi
    mv manta/results/variants/diploidSV.vcf.gz \\
        example.diploid_sv.vcf.gz
    mv manta/results/variants/diploidSV.vcf.gz.tbi \\
        example.diploid_sv.vcf.gz.tbi
    """
}

process CopyBam {
    input: tuple val(id), path(bam), path(bai)
    output: tuple path("${id}.bam"), path("${id}.bam.bai")
    script: "cp $bam ${id}.bam && cp $bai ${id}.bam.bai"
}

workflow {
    fasta = Channel.fromPath(params.fasta)
    fai = Channel.fromPath(params.fai)

    Channel.fromPath(params.input)
    | splitCsv(header: true)
    | map { row -> [row.sample, file(row.bam), file(row.bai)] }
    | CopyBam
    | toSortedList
    | transpose
    | map { [it] }
    | collect
    | set { bams }

    Manta(bams, fasta, fai)
}

