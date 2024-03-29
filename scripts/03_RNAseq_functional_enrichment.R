suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(fgsea))
suppressPackageStartupMessages(library(msigdbr))
suppressPackageStartupMessages(library(DT))
suppressPackageStartupMessages(library(clusterProfiler))
suppressPackageStartupMessages(library(org.HSapiens.gencodev30.eg.db))
suppressPackageStartupMessages(require(openxlsx))
suppressPackageStartupMessages(library(argparse))
suppressPackageStartupMessages(library(grid))

## RNAseq DEG functional analysis using topGO and keggProfiler

rm(list = ls())

source(file = "E:/Chris_UM/GitHub/omics_util/04_GO_enrichment/s01_enrichment_functions.R")
source("E:/Chris_UM/GitHub/omics_util/02_RNAseq_scripts/s02_DESeq2_functions.R")

###########################################################################

diffDataPath <- here::here("analysis", "02_DESeq2_diff")

cutoff_fdr <- 0.05
cutoff_lfc <- 0.585
cutoff_up <- cutoff_lfc
cutoff_down <- -1 * cutoff_lfc

col_lfc <- "log2FoldChange"

orgDb <- org.HSapiens.gencodev30.eg.db
keggOrg <- 'hsa'									                  ## KEGG organism code
col_degIdKeytype <- "ENSEMBL_VERSION"               ## org.db keytype of DEG file geneId
col_kegg <- "NCBI_ID"																## org.db column for NCBI ID
col_gsea <- "NCBI_ID"																## org.db column to use for gsea analysis
col_topGO <- "ENSEMBL"															## org.db keytype of topGO map file geneId
col_geneName <- "GENE_NAME"													## org.db column for Gene name
file_topGO <- "E:/Chris_UM/Database/Human/GRCh38p12.gencode30/annotation_resources/geneid2go.HSapiens.GRCh38p12.topGO.map"
file_msigDesc <- "E:/Chris_UM/Database/Human/GRCh38p12.gencode30/annotation_resources/msigDB_geneset_desc.tab"

###########################################################################
#############################################
## Run DESeq2 pipeline using Rscript       ##
## command line arguments                  ##
#############################################

parser <- ArgumentParser(
  description = "This script automates the functional enrichment analysis of RNAseq DEG results."
)

parser$add_argument(
  "-c", "--config", action="store",
  dest = "config", type = "character", nargs = 1, required = TRUE,
  # default = here::here("data", "reference_data", "polII_DESeq2_info.txt"),
  help = "DEG configuration TAB delimited file with columns: comparison, type, group1, group2, design, samples"
)

parser$add_argument(
  "-d", "--deg", action="store",
  dest = "deg", type = "character", nargs = 1, required = TRUE,
  help = "DEG comparison ID. This value should be present in the column comparison of config file"
)

# parser$print_help()

args <- parser$parse_args()

file_RNAseq_info <- args$config
degResult <- args$deg

# file_RNAseq_info <- here::here("data", "reference_data", "DESeq2_DEG_info.txt")
# degResult <- "ARID1A_KO_MEKi_vs_WT_DMSO"

outDir <- paste(diffDataPath, degResult, sep = "/")
outPrefix <- paste(outDir, degResult, sep = "/")

###########################################################################


rnaseqInfo <- get_diff_info(degInfoFile = file_RNAseq_info, dataPath = diffDataPath) %>% 
  dplyr::filter(comparison == degResult)

if(nrow(rnaseqInfo) != 1){
  stop(analysisName, " RNAseq data does not exist in config file")
}

degs <- suppressMessages(readr::read_tsv(file = rnaseqInfo$deg[1])) %>% 
  dplyr::mutate(rankMetric = (-log10(pvalue) * sign(shrinkLog2FC))) %>%
  dplyr::arrange(desc(rankMetric)) %>% 
  dplyr::filter(!is.na(rankMetric))

if(! col_gsea %in% colnames(degs)){
  gseaInfo <- suppressMessages(
    AnnotationDbi::select(x = orgDb, keys = degs$geneId,
                          keytype = col_degIdKeytype, columns = col_gsea)
  ) %>% 
    dplyr::filter(!is.na(!!sym(col_gsea))) %>% 
    dplyr::rename(geneId = !!col_degIdKeytype)
  
  degs <- dplyr::left_join(x = degs, y = gseaInfo, by = "geneId")
}

downDegs <- dplyr::filter(degs, padj <= cutoff_fdr & !!sym(col_lfc) <= cutoff_down) %>% 
  dplyr::mutate(category = "down")

upDegs <- dplyr::filter(degs, padj <= cutoff_fdr & !!sym(col_lfc) >= cutoff_up) %>% 
  dplyr::mutate(category = "up")

degData <- dplyr::bind_rows(upDegs, downDegs)

contrast <- unique(upDegs$contrast)

geneList <- dplyr::filter(degs, !is.na(!!sym(col_gsea))) %>% 
  dplyr::select(!!col_gsea, rankMetric) %>% 
  tibble::deframe()

## replace +Inf and -Inf values with max and min
geneList[is.infinite(geneList) & geneList > 0] <- max(geneList[is.finite(geneList)]) + 1

geneList[is.infinite(geneList) & geneList < 0] <- min(geneList[is.finite(geneList)]) - 1


# ###########################################################################
# ## clusterProfiler: GO enrichment
# ego_up <- enrichGO(gene = unique(upDegs$geneId),
#                    OrgDb = orgDb,
#                    ont = "BP", pAdjustMethod = "BH",
#                    pvalueCutoff = 0.05,
#                    qvalueCutoff = 0.05,
#                    keyType = "ENSEMBL",
#                    readable = FALSE)
#
# barplot(ego_up, showCategory=20)
# emapplot(ego_up, pie_scale=1.5,layout="kk", )
# cnetplot(ego_up, showCategory = 10, node_label="category")
#
# ego_up <- simplify(x = ego_up)
#
# ego_down <- enrichGO(gene = unique(downDegs$geneId),
#                      OrgDb = orgDb,
#                      ont = "BP", pAdjustMethod = "BH",
#                      pvalueCutoff = 0.05,
#                      qvalueCutoff = 0.05,
#                      keyType = "ENSEMBL",
#                      readable = FALSE)
#
# ego_down <- simplify(x = ego_down)
#
# ego_res <- dplyr::bind_rows(
#   dplyr::mutate(.data = as.data.frame(ego_up), category = "up"),
#   dplyr::mutate(.data = as.data.frame(ego_down), category = "down")
# ) %>%
#   dplyr::mutate(contrast = contrast)
#
#
# readr::write_tsv(x = ego_res, path = paste(outPrefix, ".clusterProfiler.GO.tab", sep = ""))
#
#
# ego_degs <- compareCluster(geneClusters = geneId ~ category,
#                fun = "enrichGO", data = degData,
#                OrgDb = orgDb,
#                ont = "BP", pAdjustMethod = "BH",
#                pvalueCutoff = 0.05,
#                qvalueCutoff = 0.05,
#                keyType = "ENSEMBL",
#                readable = FALSE)
#
# dotplot(ego_degs,
#         showCategory = 20)
# emapplot(ego_degs)



## topGO GO enrichment
topgo_up <- topGO_enrichment(
  goMapFile = file_topGO,
  genes = unique(upDegs$geneId),
  type = "BP", goNodeSize = 5,
  orgdb = orgDb, keytype = col_degIdKeytype,
  topgoColumn = col_topGO, geneNameColumn = col_geneName
)

topgo_down <- topGO_enrichment(
  goMapFile = file_topGO,
  genes = unique(downDegs$geneId),
  type = "BP", goNodeSize = 5,
  orgdb = orgDb, keytype = col_degIdKeytype,
  topgoColumn = col_topGO, geneNameColumn = col_geneName
)

topgo_res <- dplyr::bind_rows(
  dplyr::mutate(.data = as.data.frame(topgo_up), category = "up"),
  dplyr::mutate(.data = as.data.frame(topgo_down), category = "down")
) %>%
  dplyr::mutate(contrast = contrast)

# dplyr::glimpse(topgo_res)

readr::write_tsv(x = topgo_res, path = paste(outPrefix, ".topGO.tab", sep = ""))

## top 10 GO term bar plot
topgoPlotDf <- dplyr::group_by(topgo_res, category) %>%
  dplyr::arrange(pvalue, .by_group = TRUE) %>%
  dplyr::slice(1:10) %>%
  dplyr::ungroup()


topgo_bar <- enrichment_bar(df = topgoPlotDf,
                            title = paste(degResult, "\ntop 10 enriched GO terms in up and down DEGs"))

png(filename = paste(outPrefix, ".topGO_bar.png", sep = ""),
    width = 2500, height = 2500, res = 250)

topgo_bar
dev.off()

###########################################################################
# ## clusterProfiler: KEGG pathway enrichment
# ekegg_up <- enrichKEGG(gene = na.omit(unique(upDegs$NCBI)),
#                        organism = keggOrg,
#                        pvalueCutoff = 0.05)
#
# ekegg_down <- enrichKEGG(gene = na.omit(unique(downDegs$NCBI)),
#                          organism = keggOrg,
#                          pvalueCutoff = 0.05)
#
# ekegg_res <- dplyr::bind_rows(
#   dplyr::mutate(.data = as.data.frame(ekegg_up), category = "up"),
#   dplyr::mutate(.data = as.data.frame(ekegg_down), category = "down")
# ) %>%
#   dplyr::mutate(contrast = contrast)
#
#
# readr::write_tsv(x = ekegg_res, path = paste(outPrefix, ".clusterProfiler.kegg.tab", sep = ""))


# ## up and down DEG
# cp_kegg <- compareCluster(
#   geneClusters = list(up = na.omit(unique(upDegs$NCBI)),
#                       down = na.omit(unique(downDegs$NCBI))),
#   fun = "enrichKEGG",
#   organism = keggOrg
# )
#
# gg_cp_kegg <- dotplot(cp_kegg, showCategory = 100) +
#   labs(title = paste(analysisName, "KEGG pathway enrichment")) +
#   theme(
#     plot.title = element_text(hjust = 1)
#   )
#
#
# png(filename = paste(outPrefix, ".clusterProfiler.kegg.png", sep = ""),
#     width = 1500, height = 1500, res = 200)
#
# gg_cp_kegg
#
# dev.off()


## KEGGprofile::find_enriched_pathway
keggp_up <- keggprofile_enrichment(
  genes = unique(upDegs$geneId), orgdb = orgDb, geneNameCol = col_geneName,
  keytype = col_degIdKeytype, keggIdColumn = col_kegg, keggOrg = keggOrg
)

keggp_down <- keggprofile_enrichment(
  genes = unique(downDegs$geneId), orgdb = orgDb, geneNameCol = col_geneName,
  keytype = col_degIdKeytype, keggIdColumn = col_kegg, keggOrg = keggOrg
)

keggp_res <- dplyr::bind_rows(
  dplyr::mutate(.data = as.data.frame(keggp_up), category = "up"),
  dplyr::mutate(.data = as.data.frame(keggp_down), category = "down")
) %>%
  dplyr::mutate(contrast = contrast)

# dplyr::glimpse(keggp_res)

readr::write_tsv(x = keggp_res, path = paste(outPrefix, ".keggProfile.tab", sep = ""))

## top 10 KEGG pathway bar plot
keggPlotDf <- dplyr::group_by(keggp_res, category) %>%
  dplyr::arrange(pvalue, .by_group = TRUE) %>%
  dplyr::slice(1:10) %>%
  dplyr::ungroup()


kegg_bar <- enrichment_bar(
  df = keggPlotDf,
  title = paste(degResult, "\ntop 10 enriched KEGG pathways in up and down DEGs"),
  pvalCol = "pvalue", termCol = "Pathway_Name",
  colorCol = "category", countCol = "Observed"
)

png(filename = paste(outPrefix, ".KEGG_bar.png", sep = ""),
    width = 2500, height = 2500, res = 250)

kegg_bar
dev.off()

###########################################################################
## GSEA
msigdbr_species()
msig_df <- msigdbr(species = "Homo sapiens") %>%
  dplyr::filter(gs_cat %in% c("H", "C2", "C3", "C5")) %>%
  dplyr::filter(! gs_subcat %in% c("MF", "CC"))

# , category = c("H", "C2", "C5")
msig_list <- split(x = msig_df$entrez_gene, f = msig_df$gs_name)

# length(intersect(names(geneList), unique(msig_df$entrez_gene)))
#
# vn <- VennDiagram::venn.diagram(
#   x = list(geneList = names(geneList), msig = unique(msig_df$entrez_gene)),
#   filename = NULL,
#   print.mode = c("raw", "percent"),
#   scaled = FALSE
# )
# dev.off()
# grid.draw(vn)

msigDescDf <- suppressMessages(readr::read_tsv(file = file_msigDesc))
msigDesc <- split(x = msigDescDf$DESCRIPTION_BRIEF, f = msigDescDf$STANDARD_NAME)

# egsea <- GSEA(geneList = geneList,
#               nPerm = 10000,
#               pvalueCutoff = 0.1,
#               minGSSize = 10, maxGSSize = Inf,
#               TERM2GENE = dplyr::select(msig_df, gs_name, entrez_gene))
#
# egseaDf <- as_tibble(egsea) %>%
#   dplyr::left_join(y = msigDescDf, by = c("ID" = "STANDARD_NAME")) %>%
#   dplyr::mutate(contrast = contrast) %>%
#   dplyr::select(ID, contrast, everything(), -Description)
#
# readr::write_tsv(x = egseaDf,
#                  path = paste(outPrefix, ".clusterProfiler.GSEA.tab", sep = ""))


# ## plotting specific genesets
# genesetSub <- c("GO_CELL_CYCLE",
#                 "GO_RESPONSE_TO_ENDOPLASMIC_RETICULUM_STRESS",
#                 "GO_DNA_REPLICATION")
#
# plotList <- list()
#
# pdf(file = paste(outPrefix, ".clusterProfiler.GSEA_enrichmentPlot.pdf", sep = ""),
#     width = 10, height = 8, onefile = TRUE)
#
# for (setId in genesetSub) {
#
#   if(setId %in% egsea$ID){
#     pt <- enrichplot::gseaplot2(egsea, geneSetID = setId)
#     wrap_100 <- wrap_format(120)
#
#     plotSubTitle <- paste(
#       "p-value = ", sprintf(fmt = "%.2E", egseaDf$pvalue[which(egseaDf$ID == setId)]),
#       "; q-value = ", sprintf(fmt = "%.2E", egseaDf$qvalues[which(egseaDf$ID == setId)]),
#       "\n", wrap_100(x = msigDesc[[setId]]),
#       sep = "")
#
#     pt <- pt +
#       labs(
#         title = paste(setId, ": ", contrast, sep = ""),
#         subtitle = plotSubTitle
#       ) +
#       theme_bw() +
#       theme(panel.grid = element_blank(),
#             panel.border = element_blank())
#
#     plotList[[setId]] <- pt
#
#     plot(pt)
#
#   }
#
# }
#
# dev.off()


###########################################################################
## GSEA enrichment using fgsea
fgseaRes <- fgsea(pathways = msig_list, stats = geneList)

collapsedPathways <- collapsePathways(
  fgseaRes = fgseaRes[order(pval)][pval <= 0.05],
  pathways = msig_list,
  stats = geneList
)

uniqueFgsea <- fgseaRes[pathway %in% collapsedPathways$mainPathways]

uniqueFgsea <- dplyr::filter(uniqueFgsea, padj <= 0.05) %>%
  dplyr::left_join(y = msigDescDf, by = c("pathway" = "STANDARD_NAME")) %>%
  dplyr::mutate(
    contrast = contrast,
    leadingEdgeIds = mapIdsList(
      x = orgDb, keys = leadingEdge, column = col_degIdKeytype, keytype = col_gsea
    ),
    leadingEdgeNames = mapIdsList(
      x = orgDb, keys = leadingEdge, column = col_geneName, keytype = col_gsea
    )
  ) %>%
  dplyr::arrange(padj) %>%
  dplyr::select(pathway, DESCRIPTION_BRIEF, everything(), -starts_with("leadingEdge"),
                starts_with("leadingEdge"), -contrast, contrast)

topPathways <- uniqueFgsea[head(order(pval), n=20)][order(NES), pathway]

pt_gsea <- plotGseaTable(
  msig_list[topPathways], geneList,
  uniqueFgsea, gseaParam=0.5,
  colwidths = c(10, 5, 1, 1.5, 1.5),
  render = FALSE
)

png(filename = paste(outPrefix, ".fgsea_plot.png", sep = ""),
    width = 2500, height = 2500, res = 250)
grid::grid.draw(pt_gsea)
dev.off()

## use data.table::fwrite because of list columns
data.table::fwrite(
  x = uniqueFgsea, file = paste(outPrefix, ".fgsea.tab", sep = ""),
  sep = "\t", sep2 = c("",";",""), eol = "\n"
)

###########################################################################
# topgo_res <- suppressMessages(readr::read_tsv(file = paste(outPrefix, ".topGO.tab", sep = "")))
# keggp_res <- suppressMessages(readr::read_tsv(file = paste(outPrefix, ".keggProfile.tab", sep = "")))

## write data to excel file
descString <- paste("## log2FoldChange cutoff =", cutoff_up, "(up) /", cutoff_down, "(down)",
                    "; q-value cutoff =", cutoff_fdr)

wb <- openxlsx::createWorkbook(creator = "Lakhansing Pardeshi Genomics Core")
headerStyle <- openxlsx::createStyle(textDecoration = "bold", fgFill = "#e6e6e6")


wrkSheet <- "topGO"
openxlsx::addWorksheet(wb = wb, sheetName = wrkSheet)
openxlsx::writeData(
  wb = wb, sheet = wrkSheet, startCol = 2, startRow = 1,
  x = paste("## GO enrichment using topGO:", degResult, descString)
)
openxlsx::writeData(
  wb = wb, sheet = wrkSheet, x = topgo_res,
  startCol = 1, startRow = 2, withFilter = TRUE,
  keepNA = TRUE, na.string = "NA"
)
openxlsx::addStyle(wb = wb, sheet = wrkSheet, style = headerStyle, rows = 2, cols = 1:ncol(topgo_res))
openxlsx::setColWidths(wb = wb, sheet = wrkSheet, cols = 1, widths = "auto")
openxlsx::setColWidths(wb = wb, sheet = wrkSheet, cols = 2, widths = 60)
openxlsx::freezePane(wb = wb, sheet = wrkSheet, firstActiveRow = 3, firstActiveCol = 2)


wrkSheet <- "keggProfile"
openxlsx::addWorksheet(wb = wb, sheetName = wrkSheet)
openxlsx::writeData(
  wb = wb, sheet = wrkSheet, startCol = 2, startRow = 1,
  x = paste("KEGG pathway enrichment using keggProfiler:", degResult, descString)
)
openxlsx::writeData(
  wb = wb, sheet = wrkSheet, x = keggp_res,
  startCol = 1, startRow = 2, withFilter = TRUE,
  keepNA = TRUE, na.string = "NA"
)
openxlsx::addStyle(wb = wb, sheet = wrkSheet, style = headerStyle, rows = 2, cols = 1:ncol(keggp_res))
openxlsx::setColWidths(wb = wb, sheet = wrkSheet, cols = 1, widths = "auto")
openxlsx::setColWidths(wb = wb, sheet = wrkSheet, cols = 2, widths = 60)
openxlsx::freezePane(wb = wb, sheet = wrkSheet, firstActiveRow = 3, firstActiveCol = 2)


wrkSheet <- "fgsea"
openxlsx::addWorksheet(wb = wb, sheetName = wrkSheet)
openxlsx::writeData(
  wb = wb, sheet = wrkSheet, startCol = 2, startRow = 1,
  x = paste("preranked gene set enrichment analysis (GSEA):", degResult)
)
openxlsx::writeData(
  wb = wb, sheet = wrkSheet, x = uniqueFgsea,
  startCol = 1, startRow = 2, withFilter = TRUE,
  keepNA = TRUE, na.string = "NA"
)
openxlsx::addStyle(wb = wb, sheet = wrkSheet, style = headerStyle, rows = 2, cols = 1:ncol(uniqueFgsea))
openxlsx::setColWidths(wb = wb, sheet = wrkSheet, cols = 1, widths = 60)
openxlsx::setColWidths(wb = wb, sheet = wrkSheet, cols = 2, widths = 60)
openxlsx::freezePane(wb = wb, sheet = wrkSheet, firstActiveRow = 3, firstActiveCol = 2)

# openxlsx::openXL(wb)
openxlsx::saveWorkbook(wb = wb, file = paste(outPrefix, ".enrichment.xlsx", sep = ""), overwrite = TRUE)

###########################################################################



