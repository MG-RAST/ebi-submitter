cwlVersion: v1.0
class: Workflow

requirements:
    ScatterFeatureRequirement: {}
    MultipleInputFeatureRequirement: {}

inputs:
    seqFiles:
        type:
            type: array
            items:
                type: record
                fields:
                    - name: file
                      type: File
                      doc: Input sequence file
                    - name: mgid
                      type: string
                      doc: MG-RAST ID of sequence file
        doc: Array of MG-RAST ID and sequence tuples

outputs:
    trimmedSeqs:
        type:
            type: array
            items:
                type: record
                fields:
                    - name: file
                      type: File
                      doc: Input sequence file
                    - name: mgid
                      type: string
                      doc: MG-RAST ID of sequence file
        outputSource: [trimmer/trimmed]

steps:
    trimmer:
        run: ../tools/autoskewer.tool.cwl
        scatter: "#trimmer/input"
        in:
            input: seqFiles
            outName:
                source: seqFiles
                valueFrom: $(self).trim
        out: [trimmed]
