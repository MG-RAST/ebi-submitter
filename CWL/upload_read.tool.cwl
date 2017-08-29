cwlVersion: v1.0
class: CommandLineTool

label: EBI upload read
doc: |
    upload read sequence file (fasta or fastq) to EBI ftp inbox: adaptor trim / compress / md5sum
    >upload_read.pl -input=<input> -output=<outName> -mgid=<mgID> -updir=<uploadDir> -furl=<ftpUrl> -user=<ftpUser> -pswd=<ftpPassword> -tmpdir=<tmpDir> -trim <toTrim>

hints:
    DockerRequirement:
        dockerPull: mgrast/ebi:0.2

requirements:
    InlineJavascriptRequirement: {}

stdout: upload_read.log
stderr: upload_read.error

inputs:
    input:
        type: File
        doc: Input sequence file
        format:
            - Formats:fasta
            - Formats:fastq
        inputBinding:
            prefix: --input
    
    uploadDir:
        type: string
        doc: Upload dir on ftp site
        inputBinding:
            prefix: --updir
    
    mgID:
        type: string?
        doc: Optional MG-RAST Metagenome ID
        inputBinding:
            prefix: --mgid
    
    ftpUrl:
        type: string?
        doc: Optional ftp url
        default: webin.ebi.ac.uk
        inputBinding:
            prefix: --furl
    
    ftpUser:
        type: string?
        doc: Optional ftp login name
        inputBinding:
            prefix: --user
    
    ftpPassword:
        type: string?
        doc: Optional ftp login password
        inputBinding:
            prefix: --pswd
    
    toTrim:
        type: boolean?
        doc: Optional, run adaptor trim
        inputBinding:
            prefix: --trim
    
    outName:
        type: string
        doc: Output upload info
        inputBinding:
            prefix: --output


baseCommand: [upload_read.pl]

arguments:
    - prefix: --format
      valueFrom: $(inputs.input.format)
    - prefix: --tmpdir
      valueFrom: $(runtime.tmpdir)

outputs:
    info:
        type: stdout
    error: 
        type: stderr  
    output:
        type: File
        doc: Output upload info file
        outputBinding: 
            glob: $(inputs.outName)

$namespaces:
    Formats: FileFormats.cv.yaml

