library(tidyverse)


rm(list = ls())

###########################################################################
#######################
### DESeq2 pairwise ###
#######################

# ## RNAseq DESeq2 differential gene expression batches
# file_RNAseq_info <-here::here("data", "reference_data", "DESeq2_DEG_info.txt")
# diffDataPath <- here::here("analysis", "02_DESeq2_diff")
# script_deseq2 <- here::here("scripts", "02_DESeq2_pairwise.R")
# 
# runConfig <- suppressMessages(readr::read_tsv(file_RNAseq_info))
# 
# i <- 1
# 
# for (i in 1:nrow(runConfig)) {
# 
#   system2(
#     command = "Rscript",
#     args = c(script_deseq2, "--config", file_RNAseq_info, "--deg", runConfig$comparison[i]),
#     stdout = paste("logs/stdouterr.DESeq2.", runConfig$comparison[i],".log", sep = ""),
#     stderr = paste("logs/stdouterr.DESeq2.", runConfig$comparison[i],".log", sep = "")
#   )
# 
# }



###########################################################################
####################################
### DESeq2 Functional enrichment ###
####################################

file_RNAseq_info <-here::here("data", "reference_data", "DESeq2_DEG_info.txt")
script_deseq2_GO <- here::here("scripts", "03_RNAseq_functional_enrichment.R")

runConfig <- suppressMessages(readr::read_tsv(file_RNAseq_info))

i <- 1

for (i in 1:nrow(runConfig)) {

  system2(
    command = "Rscript",
    # args = c(script_deseq2_GO, "--help"),
    args = c(script_deseq2_GO, "--config", file_RNAseq_info, "--deg", runConfig$comparison[i]),
    stdout = paste("logs/stdouterr.functional_enrichment.", runConfig$comparison[i],".log", sep = ""),
    stderr = paste("logs/stdouterr.functional_enrichment.", runConfig$comparison[i],".log", sep = "")
  )

}

###########################################################################

# ###############################
# ### Pairwise DEG comparison ###
# ###############################
# 
# file_conf <- here::here("analysis", "04_DEG_compare", "DEG_pair_compare.conf.tab")
# 
# runConfig <- suppressMessages(readr::read_tsv(file_conf))
# script_degPairComp <- here::here("scripts", "05_RNAseq_compare_DEG_pairs.R")
# 
# i <- 1
# 
# for (i in 1:nrow(runConfig)) {
#   
#   system2(
#     command = "Rscript",
#     # args = c(script_degPairComp, "--help"),
#     args = c(script_degPairComp, "--config", file_conf, "--pair", runConfig$degPairId[i]),
#     stdout = paste("logs/stdouterr.compare_deg_pair.", runConfig$degPairId[i],".log", sep = ""),
#     stderr = paste("logs/stdouterr.compare_deg_pair.", runConfig$degPairId[i],".log", sep = "")
#   )
#   
# }

###########################################################################
#
# ## copy results for sharing
# file_RNAseq_info <-here::here("data", "reference_data", "DESeq2_DEG_info.txt")
# diffDataPath <- here::here("analysis", "02_DESeq2_diff")
#
# runConfig <- suppressMessages(readr::read_tsv(file_RNAseq_info))
#
# tempStore <- here::here("analysis", "temp_store")
# dir.create(tempStore)
# i <- 1
#
# for (i in 1:nrow(runConfig)) {
#
#   newDir <- paste(tempStore, "/", runConfig$comparison[i], sep = "")
#   dir.create(newDir)
#
#   file_deseq2Res <- paste(diffDataPath, "/", runConfig$comparison[i], "/", runConfig$comparison[i], ".DEG_all.xlsx", sep = "")
#   file_enrich <- paste(diffDataPath, "/", runConfig$comparison[i], "/", runConfig$comparison[i], ".enrichment.xlsx", sep = "")
#   file_plots <- paste(diffDataPath, "/", runConfig$comparison[i], "/", runConfig$comparison[i], ".summary_plots.pdf", sep = "")
#   file_volc <- paste(diffDataPath, "/", runConfig$comparison[i], "/", runConfig$comparison[i], ".PCA_volcano.png", sep = "")
#   # file_heatmap <- paste(diffDataPath, "/", runConfig$comparison[i], "/", runConfig$comparison[i], ".normCount_heatmap.pdf", sep = "")
#
#   file.copy(from = file_deseq2Res, to = newDir)
#   file.copy(from = file_enrich, to = newDir)
#   file.copy(from = file_plots, to = newDir)
#   file.copy(from = file_volc, to = newDir)
#   # file.copy(from = file_heatmap, to = newDir)
#
# }




#
#
# library(org.Anidulans.FGSCA4.eg.db)
# orgDb <- org.Anidulans.FGSCA4.eg.db
#
# keytypes(orgDb)
#
# df <- AnnotationDbi::select(x = orgDb, keys = keys(orgDb), columns = c("GOALL", "ONTOLOGYALL"))
#
# goTerms <- AnnotationDbi::select(x = GO.db, keys = unique(df$GOALL), columns = "TERM")
#
# df <- dplyr::left_join(x = df, y = goTerms, by = c("GOALL" = "GOID"))
#
# data <- dplyr::group_by(df, GID) %>%
#   dplyr::summarise(
#     GOALL = paste(GOALL, collapse = ";"),
#     ONTOLOGYALL = paste(ONTOLOGYALL, collapse = ";"),
#     TERM = paste(TERM, collapse = " | "),
#   )
#
# readr::write_tsv(x = data, path = "AN.GO_data.tab")
#
#
