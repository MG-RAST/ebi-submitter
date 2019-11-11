cwlVersion: v1.1
class: CommandLineTool

label: submit MG-RAST Project
doc: |
    create the ENA XML files for a MG-RAST Project and submit them to EBI
    >submit_project.pl

requirements:
    InlineJavascriptRequirement: {}

stdout: submit_project.log
stderr: submit_project.error

inputs:
    project:
        type: string
        doc: MG-RAST Project ID
        inputBinding:
            prefix: --project_id
    
    uploads:
        type: File
        doc: Metagenome upload list file
        inputBinding:
            prefix: --upload_list
    
    outName:
        type: string?
        doc: Submission receipt
        default: receipt.xml
        inputBinding:
            prefix: --output
    
    mgrastUrl:
        type: string?
        doc: MG-RAST API URL
        inputBinding:
            prefix: --mgrast_url
    
    submitUrl:
        type: string?
        doc: EBI Submission URL
        inputBinding:
            prefix: --submit_url
    
    submitUser:
        type: string?
        doc: Optional Submission URL login
        inputBinding:
            prefix: --user
    
    submitPassword:
        type: string?
        doc: Optional Submission URL password
        inputBinding:
            prefix: --password
    
    submitOption:
        type: string?
        doc: Optional Submission type
        default: ADD
        inputBinding:
            prefix: --submit_option
    
    submissionID:
        type: string?
        doc: Optional Submission ID
        inputBinding:
            prefix: --submission_id


baseCommand: submit_project.pl

arguments:
    - prefix: --verbose

outputs:
    info:
        type: stdout
    error: 
        type: stderr
    outReceipt:
        type: File
        doc: Submission receipt file
        outputBinding:
            glob: $(inputs.outName)
    outSubmission:
        type: File
        doc: Submission xml file
        outputBinding:
            glob: submission.xml
    outStudy:
        type: File
        doc: Study xml file
        outputBinding:
            glob: study.xml
    outSample:
        type: File
        doc: Sample xml file
        outputBinding:
            glob: sample.xml
    outExperiment:
        type: File
        doc: Experiment xml file
        outputBinding:
            glob: experiment.xml
    outRun:
        type: File
        doc: Run xml file
        outputBinding:
            glob: run.xml

