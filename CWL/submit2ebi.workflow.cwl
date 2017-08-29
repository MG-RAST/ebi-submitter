cwlVersion: v1.0
class: Workflow

requirements:
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement

inputs:
    seqFiles:
        type:
            type: array
            items: File
    mgIDs:
        type:
            type: array
            items: string
    project:
        type: string
    user:
        type: string
    password:
        type: string
    submitOption:
        type: string

outputs:
    receipt:
        type: File
        outputSource: submitter/output

steps:
    trimmer:
        run: autoskewer.tool.cwl
        scatter: "#trimmer/input"
        in:
            input: seqFiles
            outName:
                source: seqFiles
                valueFrom: $(self).trim
        out: [trimmedSeq]

    uploader:
        run: upload_read.tool.cwl
        scatter: "#uploader/input"
        scatter: "#uploader/mgID"
        in:
            input: trimmer/trimmedSeq
            mgID: mgIDs
            uploadDir: project
            ftpUser: user
            ftpPassword: password
            outName:
                source: trimmer/trimmedSeq
                valueFrom: $(self).info
        out: [output]

    cat:
        run: cat.tool.cwl
        in:
            files: uploader/output
            outName:
                source: project
                valueFrom: $(self).mg.upload
        out: output

    submitter:     	 
        run: submit_project.tool.cwl
        in:
            uploads: cat/output
            project: project
            submitUser: user
            submitPassword: password
            submitOption: submitOption
            outName:
                source: cat/output
                valueFrom: $(self).receipt.xml
        out: output
 
 