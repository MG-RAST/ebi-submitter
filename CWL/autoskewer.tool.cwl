cwlVersion: v1.0
class: CommandLineTool

label: autoskewer
doc: |
    detect and trim adapter sequences from reads
    >autoskewer.py -t <runtime.tmpdir> -i <input> -o <outName> -l <outLog>

hints:
    DockerRequirement:
        dockerPull: wilke/autoskewer:0.1
    
requirements:
    InlineJavascriptRequirement: {}

stdout: autoskewer.log
stderr: autoskewer.error

inputs:
    input:
        type: File
        doc: Input sequence file
        format:
            - Formats:fasta
            - Formats:fastq
        inputBinding:
            prefix: -i
    outName:
        type: string
        doc: Output trimmed sequences
        inputBinding:
            prefix: -o
    outLog:
        type: string
        doc: Output trimmed log
        inputBinding:
            prefix: -l


baseCommand: autoskewer.py

arguments:
    - prefix: -t
      valueFrom: $(runtime.tmpdir)

outputs:
    info:
        type: stdout
    error: 
        type: stderr
    trimmedSeq:
        type: File
        doc: Output trimmed sequences file
        outputBinding:
            glob: $(inputs.outName)
    trimmedLog:
        type: File
        doc: Output trimmed log file
        outputBinding:
            glob: $(inputs.outLog)

$namespaces:
    Formats: FileFormats.cv.yaml
