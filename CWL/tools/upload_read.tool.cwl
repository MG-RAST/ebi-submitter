cwlVersion: v1.0
class: CommandLineTool

label: EBI upload read
doc: |
    upload read sequence file (fasta or fastq) to EBI ftp inbox: adaptor trim / compress / md5sum
    >upload_read.pl -input=<input> -output=<outName> -mgid=<mgID> -updir=<uploadDir> -furl=<ftpUrl> -user=<ftpUser> -pswd=<ftpPassword> -tmpdir=<tmpDir>

hints:
    DockerRequirement:
        dockerPull: mgrast/ebi:0.2

requirements:
    InlineJavascriptRequirement: {}

stdout: upload_read.log
stderr: upload_read.error

inputs:
    input:
        type:
            type: record
            fields:
                - name: file
                  type: File
                  doc: Input sequence file
                - name: mgid
                  type: string
                  doc: MG-RAST ID of sequence file
        doc: MG-RAST ID and sequence tuple
    
    uploadDir:
        type: string
        doc: Upload dir on ftp site
        inputBinding:
            prefix: --updir
    
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
    
    outName:
        type: string
        doc: Output upload info
        inputBinding:
            prefix: --output


baseCommand: [upload_read.pl]

arguments:
    - prefix: --input
      valueFrom: $(inputs.input.file)
    - prefix: --mgid
      valueFrom: $(inputs.input.mgid)
    - prefix: --format
      valueFrom: |
          ${
              if (inputs.input.file.format) {
                  return inputs.input.file.format.split("/").slice(-1)[0];
              } else {
                  return null;
              }
          }

outputs:
    info:
        type: stdout
    error: 
        type: stderr
    outInfo:
        type: File
        doc: Output upload info file
        outputBinding:
            glob: $(inputs.outName)
    outGzip:
        type: File
        doc: Gzipped file that was uploaded
        outputBinding:
            glob:
                glob: $(inputs.input.file).gz

