cwlVersion: v1.0
class: Workflow

requirements:
    ScatterFeatureRequirement: {}
    MultipleInputFeatureRequirement: {}
    StepInputExpressionRequirement: {}

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
    project:
        type: string
    user:
        type: string
    password:
        type: string

outputs:
    uploadFiles:
        type: File[]
        outputSource: uploader/outGzip
    uploadInfo:
        type: File
        outputSource: cat/output

steps:
    trimmer:
        run: ../tools/autoskewer.tool.cwl
        scatter: ["#trimmer/input", "#trimmer/outName"]
        scatterMethod: dotproduct
        in:
            input: seqFiles
            outName:
                source: seqFiles
                valueFrom: $(self.file.basename).trim
        out: [trimmed]
    
    uploader:
        run: ../tools/upload_read.tool.cwl
        scatter: ["#uploader/input", "#uploader/outName"]
        scatterMethod: dotproduct
        in:
            input: trimmer/trimmed
            uploadDir: project
            ftpUser: user
            ftpPassword: password
            outName:
                source: trimmer/trimmed
                valueFrom: $(self.file.basename).info
        out: [outInfo, outGzip]

    cat:
        run: ../tools/cat.tool.cwl
        in:
            files: uploader/outInfo
            outName:
                source: project
                valueFrom: $(self).mg.upload
        out: [output]

