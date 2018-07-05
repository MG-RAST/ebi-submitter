cwlVersion: v1.0
class: Workflow

requirements:
    InlineJavascriptRequirement: {}
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
    mgrastUrl:
        type: string
    mgrastToken:
        type: string
    submitUrl:
        type: string
    user:
        type: string
    password:
        type: string
    submitOption:
        type: string
    submissionID:
        type: string

outputs:
    trimError:
        type: File
        outputSource: mergeTrimError/output
    uploaded:
        type: File[]
        outputSource: uploader/outGzip
    uploadError:
        type: File
        outputSource: mergeUploadError/output
    receipt:
        type: File
        outputSource: submitter/outReceipt
    submission:
        type: File
        outputSource: submitter/outSubmission
    study:
        type: File
        outputSource: submitter/outStudy
    sample:
        type: File
        outputSource: submitter/outSample
    experiment:
        type: File
        outputSource: submitter/outExperiment
    run:
        type: File
        outputSource: submitter/outRun
    submitError:
        type: File
        outputSource: submitter/error
    accessionLog:
        type: File
        outputSource: finalize/output

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
        out: [trimmed, error]

    mergeTrimError:
        run: ../tools/cat.tool.cwl
        in:
            files: trimmer/error
            outName: autoskewer.error
        out: [output]

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
        out: [outInfo, outGzip, error]

    mergeInfo:
        run: ../tools/cat.tool.cwl
        in:
            files: uploader/outInfo
            outName:
                source: project
                valueFrom: $(self).mg.upload
        out: [output]
    
    mergeUploadError:
        run: ../tools/cat.tool.cwl
        in:
            files: uploader/error
            outName: upload_read.error
        out: [output]

    submitter:
        run: ../tools/submit_project.tool.cwl
        in:
            uploads: mergeInfo/output
            project: project
            mgrastUrl: mgrastUrl
            submitUrl: submitUrl
            submitUser: user
            submitPassword: password
            submitOption: submitOption
            submissionID: submissionID
            outName:
                source: project
                valueFrom: $(self).receipt.xml
        out: [outReceipt, outSubmission, outStudy, outSample, outExperiment, outRun, error]

    finalize:
        run: ../tools/curl.tool.cwl
        in:
            label:
                default: receipt
            file: submitter/outReceipt
            authBearer:
                default: mgrast
            authToken: mgrastToken
            url:
                source: [mgrastUrl, project]
                valueFrom: |
                    ${
                        return self[0]+"/project/"+self[1]+"/addaccession";
                    }
            outName:
                source: project
                valueFrom: $(self).receipt.json
        out: [output]
 
 