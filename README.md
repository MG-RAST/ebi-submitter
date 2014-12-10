ebi-submitter
=============

Tools for submitting public MG-RAST jobs to the EBI's ENA archive
==============

Scripts for data publication from MG-RAST to the EBI's ENA archive. Our contact at EBI is Guy Cochrane (Guy Cochrane <cochrane@ebi.ac.uk>).

In short: we are adding an upload to EBI stage in MG-RAST as an AWE stage and adding a button in the project view.

It will be triggered on a per project basis by the end user once the data has finished loading (similar to re-uploading the metadata on the project page currently). Users will also be able to re-upload their data for updating what is represented @ EBI. (Theoretically users can also delete data once submitted to EBI via a suppression request, but we will to not support this, once submitted to EBI it is permanently public). Only data public in MG-RAST will be submitted to EBI (taking things back is not an option).

MG-RAST  will be shown as broker on each record, but ownership will be preserved.

This is EBI's main page for uploads: http://www.ebi.ac.uk/ena/submit

The format of the XML files to be submitted is here http://www.ebi.ac.uk/ena/submit/preparing-xmls

Current open Issues:
-------

* we need to capture from the users for this the NCBI taxonomy 

Pick one of the two below:

*  http://www.ebi.ac.uk/ena/data/view/Taxon:410657&display=xml&download=xml&filename=410657.xml for non-host-associated.
*  http://www.ebi.ac.uk/ena/data/view/Taxon:410656&display=xml&download=xml&filename=410656.xml for host-associated.
* for browsing try: http://www.ebi.ac.uk/ena/data/view/Taxon:410656 (wait a bit and click on the tree tab).

we also need the platform one of the below:

*  LS454
*  ILLUMINA
*  COMPLETE_GENOMICS
* PACBIO_SMRT
*  ION_TORRENT
* OXFORD_NANOPORE
*  CAPILLARY

Both of these data points we should actually capture with the metadata up front, we should check if the project has this data (per job) and then fill local metadata before submitting with the info to EBI.







