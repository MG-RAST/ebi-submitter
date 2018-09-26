cwlVersion: v1.0
class: CommandLineTool

label: EBI receipt validation
doc: |
    upload read sequence file (fasta or fastq) to EBI ftp inbox: adaptor trim / compress / md5sum
    >validate_receipt.pl -input=<receipt>

requirements:
    InlineJavascriptRequirement: {}

stdout: validate_receipt.log
stderr: validate_receipt.error

inputs:
    receipt:
        type: File
        doc: EBI submission receipt
        inputBinding:
            prefix: --input

baseCommand: [validate_receipt.pl]

outputs:
    info:
        type: stdout
    error: 
        type: stderr

