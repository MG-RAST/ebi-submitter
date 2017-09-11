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
    SchemaDefRequirement:
        types:
            - $import: mgfile.yaml

stdout: upload_read.log
stderr: upload_read.error

inputs:
    input:
        type: mgfile.yaml#mgfile
    
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

