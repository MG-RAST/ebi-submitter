cwlVersion: v1.0
class: Workflow

requirements:
    ScatterFeatureRequirement: {}
    MultipleInputFeatureRequirement: {}
    SchemaDefRequirement:
        types:
            - $import: ../tools/mgfile.yaml

inputs:
    seqFiles:
        type:
            type: array
            items: ../tools/mgfile.yaml#mgfile

outputs:
    trimmedSeqs:
        type: ../tools/mgfile.yaml#mgfile[]
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
