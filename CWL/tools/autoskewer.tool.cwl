cwlVersion: v1.0
class: CommandLineTool

label: autoskewer
doc: |
    detect and trim adapter sequences from reads
    >autoskewer.py -t <runtime.tmpdir> -i <input> -o <outName> -l <outLog>

hints:
    DockerRequirement:
        dockerPull: mgrast/ebi:0.2
    
requirements:
    InlineJavascriptRequirement: {}
    SchemaDefRequirement:
        types:
            - $import: mgfile.yaml

stdout: autoskewer.log
stderr: autoskewer.error

inputs:
    input:
        type: mgfile.yaml#mgfile
    
    outName:
        type: string
        doc: Output trimmed sequences
        inputBinding:
            prefix: -o
    
    outLog:
        type: string?
        doc: Optional output trimmed log
        inputBinding:
            prefix: -l


baseCommand: autoskewer.py

arguments:
    - prefix: -i
      valueFrom: $(inputs.input.file)
    - prefix: -t
      valueFrom: $(runtime.tmpdir)

outputs:
    info:
        type: stdout
    error: 
        type: stderr
    trimmed:
        type:
            type: record
            fields:
                - name: file
                  type: File
                  doc: Output trimmed sequences file
                  outputBinding:
                      glob: $(inputs.outName)
                      outputEval: |
                          ${
                              self[0].format = inputs.input.file.format;
                              return self[0];
                          }
                - name: mgid
                  type: string
                  doc: MG-RAST ID of sequence file
                  outputBinding:
                      outputEval: $(inputs.input.mgid)
        doc: MG-RAST ID and sequence tuple
    trimmedLog:
        type: File?
        doc: Optional output trimmed log file
        outputBinding:
            glob: $(inputs.outLog)

