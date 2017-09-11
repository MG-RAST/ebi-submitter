cwlVersion: v1.0
class: Workflow

requirements:
    ScatterFeatureRequirement: {}
    MultipleInputFeatureRequirement: {}
    SchemaDefRequirement:
        types:
            - $import: mgfile.yaml

inputs:
    seqFiles:
        type:
            type: array
            items: mgfile.yaml#mgfile

outputs:
    trimmedSeqs:
        type:
            type: array
            items: mgfile.yaml#mgfile
        outputSource: trimmer/trimmed

steps:
    trimmer:
        run: autoskewer.tool.cwl
        scatter: "#trimmer/input"
        in:
            input: seqFiles
            outName:
                source: seqFiles
                valueFrom: $(self).trim
        out: [trimmedSeqs]
