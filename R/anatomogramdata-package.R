# hgMale/hgFemale/organ_systems are lazy-loaded package data, referenced by
# bare name inside anatomogram_select() -- R CMD check's static analysis
# can't tell these apart from real undefined globals without this.
utils::globalVariables(c("hgMale", "hgFemale", "organ_systems"))
