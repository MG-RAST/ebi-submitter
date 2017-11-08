package Submitter::Mixs;

use strict;
use warnings;

sub term_map {
    return {
        # project level
        project_name       => ["project name", undef],
        # library level
        investigation_type => ["investigation type", undef],
        seq_meth           => ["sequencing method", undef],
        # sample level
        collection_date    => ["collection date", undef],
        country            => ["geographic location (country and/or sea)", undef],
        location           => ["geographic location (region and locality)", undef],
        latitude           => ["geographic location (latitude)", "DD"],
        longitude          => ["geographic location (longitude)", "DD"],
        altitude           => ["geographic location (altitude)", "m"],
        depth              => ["geographic location (depth)", "m"],
        elevation          => ["geographic location (elevation)", "m"],
        biome              => ["environment (biome)", undef],
        feature            => ["environment (feature)", undef],
        material           => ["environment (material)", undef],
        env_package        => ["environmental package", undef],
        # environmental package specific
        ammonium           => ["ammonium", "µmol/L"],
        magnesium          => ["magnesium", "mol/L"],
        nitrate            => ["nitrate", "µmol/L"],
        salinity           => ["salinity", "psu"],
        sulfate            => ["sulfate", "µmol/L"],
        sulfide            => ["sulfide", "µmol/L"],
        temperature        => ["temperature", "ºC"]
    };
}

sub seq_meth_map {
    return {
        LS454             => 1,
        ILLUMINA          => 1,
        HELICOS           => 1,
        ABI_SOLID         => 1,
        COMPLETE_GENOMICS => 1,
        BGISEQ            => 1,
        OXFORD_NANOPORE   => 1,
        PACBIO_SMRT       => 1,
        ION_TORRENT       => 1,
        CAPILLARY         => 1
    };
}

sub library_map {
    return {
        'metagenome' => {
            strategy => "WGS",
            source   => "METAGENOMIC"
        },
        'mimarks-survey' => {
            strategy => "AMPLICON",
            source   => "METAGENOMIC"
        },
        'metatranscriptome' => {
            strategy => "RNA-Seq",
            source   => "METATRANSCRIPTOMIC"
        }
    };
}

sub env_package_map {
    return {
        "air"                   => {
            checklist => "ERC000012",
            fullname  => "air environmental package"
        },
        "built environment"     => {
            checklist => "ERC000031",
            fullname  => "built environment environmental package"
        },
        "host-associated"       => {
            checklist => "ERC000013",
            fullname  => "host-associated environmental package"
        },
        "human-associated"      => {
            checklist => "ERC000014",
            fullname  => "human-associated environmental package"
        },
        "human-gut"             => {
            checklist => "ERC000015",
            fullname  => "human gut environmental package"
        },
        "human-oral"            => {
            checklist => "ERC000016",
            fullname  => "human oral environmental package"
        },
        "human-skin"            => {
            checklist => "ERC000017",
            fullname  => "human skin environmental package"
        },
        "human-vaginal"         => {
            checklist => "ERC000018",
            fullname  => "human vaginal environmental package"
        },
        "microbial mat|biofilm" => {
            checklist => "ERC000019",
            fullname  => "microbial mat/biofilm environmental package"
        },
        "miscellaneous"         => {
            checklist => "ERC000025",
            fullname  => "miscellaneous environmental package"
        },
        "plant-associated"      => {
            checklist => "ERC000020",
            fullname  => "plant-associated environmental package"
        },
        "sediment"              => {
            checklist => "ERC000021",
            fullname  => "sediment environmental package"
        },
        "soil"                  => {
            checklist => "ERC000022",
            fullname  => "soil environmental package"
        },
        "wastewater|sludge"     => {
            checklist => "ERC000023",
            fullname  => "wastewater/sludge environmental package"
        },
        "water"                 => {
            checklist => "ERC000024",
            fullname  => "water environmental package"
        }
    };
}

1;
