#' draw an oncostrip similar to cBioportal oncoprinter output.
#'
#' @param maf an \code{\link{MAF}} object generated by \code{read.maf}
#' @param genes draw oncoprint for these genes. default NULL. Plots top 5 genes.
#' @param sort logical sort oncomatrix for enhanced visualization. Defaults to TRUE.
#' @param sortByAnnotation logical sort oncomatrix by provided annotations. Defaults to FALSE. This is mutually exclusive with \code{sort}.
#' @param annotation \code{data.frame} with first column containing Tumor_Sample_Barcodes and rest of columns with annotations.
#' @param top how many top genes to be drawn. defaults to 5.
#' @param removeNonMutated Logical. If \code{TRUE} removes samples with no mutations in the oncoplot for better visualization. Default TRUE.
#' @param showTumorSampleBarcodes logical to include sample names.
#' @param colors named vector of colors for each Variant_Classification.
#' @param annotationColor list of colors to use for annotation. Default NULL.
#' @return None.
#' @seealso \code{\link{oncoplot}}
#' @examples
#' laml.maf <- system.file("extdata", "tcga_laml.maf.gz", package = "maftools")
#' laml <- read.maf(maf = laml.maf, removeSilent = TRUE, useAll = FALSE)
#' dev.new()
#' oncostrip(maf = laml, genes = c('NPM1', 'RUNX1'), removeNonMutated = TRUE)
#'
#' @export


oncostrip = function(maf, genes = NULL, sort = TRUE, sortByAnnotation = FALSE, annotation = NULL, annotationColor = NULL, removeNonMutated = TRUE, top = 5, showTumorSampleBarcodes = FALSE, colors = NULL){

  mat_origin = maf@numericMatrix

  if(ncol(mat_origin) < 2){
    stop('Cannot create oncoplot for single sample. Minimum two sample required ! ')
  }

  if(nrow(mat_origin) <2){
    stop('Minimum two genes required !')
  }

  #if user doesnt provide a gene vector, use top 5.
  if(is.null(genes)){
    mat = mat_origin[1:top, ]
  } else{
    mat = mat_origin[genes,]
  }

  #remove nonmutated samples to improve visualization
  if(removeNonMutated){
    tsb = colnames(mat)
    tsb.exclude = colnames(mat[,colSums(mat) == 0])
    tsb.include = tsb[!tsb %in% tsb.exclude]
    mat = mat[,tsb.include]
  }

  #Sort
  if(sortByAnnotation){
    if(is.null(annotation)){
      stop("Missing annotation data. Use argument `annotation` to provide annotations.")
    }
    mat = sortByAnnotation(mat,maf,annotation)
  }else{
    if(sort){
      mat = sortByMutation(numMat = mat, maf = maf)
    }
  }

  char.mat = maf@oncoMatrix
  char.mat = char.mat[rownames(mat),]
  char.mat = char.mat[,colnames(mat)]
  #final matrix for plotting
  mat = char.mat

  #New version of complexheatmap complains about '' , replacing them with random strinf xxx
  mat[mat == ''] = 'xxx'

  #---------------------------------------Colors and vcs-------------------------------------------------

  if(is.null(colors)){
    col = c(RColorBrewer::brewer.pal(12,name = "Paired"), RColorBrewer::brewer.pal(11,name = "Spectral")[1:3],'black', 'violet', 'royalblue')
    names(col) = names = c('Nonstop_Mutation','Frame_Shift_Del','IGR','Missense_Mutation','Silent','Nonsense_Mutation',
                           'RNA','Splice_Site','Intron','Frame_Shift_Ins','Nonstop_Mutation','In_Frame_Del','ITD','In_Frame_Ins',
                           'Translation_Start_Site',"Multi_Hit", 'Amp', 'Del')
  }else{
    col = colors
  }

  #Default background gray color.
  bg = "#CCCCCC"
  #New version of complexheatmap complains about '', will replace them with random tesx, xxx
  col = c(col, 'xxx' = bg)


  variant.classes = unique(unlist(as.list(apply(mat, 2, unique))))
  variant.classes = unique(unlist(strsplit(x = variant.classes, split = ';', fixed = TRUE)))

  variant.classes = variant.classes[!variant.classes %in% c('xxx')]

  type_col = structure(col[variant.classes], names = names(col[variant.classes]))
  type_col = type_col[!is.na(type_col)]

  type_name = structure(variant.classes, names = variant.classes)

  variant.classes = variant.classes[!variant.classes %in% c('Amp', 'Del')]

  #Make annotation
  if(!is.null(annotation)){
    annotation[,1] = gsub(pattern = '-', replacement = '.', x = annotation[,1])

    if(nrow(annotation[duplicated(annotation$Tumor_Sample_Barcode),]) > 0){
      annotation = annotation[!duplicated(annotation$Tumor_Sample_Barcode),]
    }

    rownames(annotation) = annotation[,1]
    annotation = annotation[complete.cases(annotation),]
    annot.order = rownames(annotation)
    anno.df = data.frame(row.names = annotation[,1])
    anno.df = cbind(anno.df, annotation[,2:ncol(annotation)])
    colnames(anno.df) = colnames(annotation)[2:ncol(annotation)]
    #needed such that the annotation order matches the sample order if any type of sort is used
    if(sort || sort_by_anno){
      sorted.order = colnames(mat)
      anno.df.sorted = as.data.frame(anno.df[sorted.order,])
      rownames(anno.df.sorted) = sorted.order
      colnames(anno.df.sorted) = colnames(anno.df)
      anno.df = anno.df.sorted
    }

    if(!is.null(annotationColor)){
      bot.anno = HeatmapAnnotation(df = anno.df, col = annotationColor)
    }else{
      bot.anno = HeatmapAnnotation(anno.df)
    }
  }

  #------------------------------------Helper functions to add %, rowbar and colbar----------------------------------------------------
  ##This function adds percent rate
  anno_pct = function(index) {
    n = length(index)
    pct = apply(mat_origin[rev(index), ], 1, function(x) sum(!grepl("^\\s*$", x))/length(x)) * 100
    pct = paste0(round(pct), "%")
    grid::pushViewport(viewport(xscale = c(0, 1), yscale = c(0.5, n + 0.5)))
    grid::grid.text(pct, x = 1, y = seq_along(index), default.units = "native",
                    just = "right", gp = grid::gpar(fontsize = 10))
    grid::upViewport()
  }

  ha_pct = ComplexHeatmap::HeatmapAnnotation(pct = anno_pct,
                                             width = grid::grobWidth(grid::textGrob("100%", gp = grid::gpar(fontsize = 10))), which = "row")

  ##Following two funcs add grids
  add_oncoprint = function(type, x, y, width, height) {
    grid::grid.rect(x, y, width - unit(0.5, "mm"),
                    height - grid::unit(1, "mm"), gp = grid::gpar(col = NA, fill = bg))

    for (i in 1:length(variant.classes)) {
      if (any(type %in% variant.classes[i])) {
        grid::grid.rect(x, y, width - unit(0.5, "mm"), height -
                          grid::unit(1, "mm"), gp = grid::gpar(col = NA, fill = type_col[variant.classes[i]]))
      } else if (any(type %in% 'Amp')) {
        grid::grid.rect(x, y, width - unit(0.5, "mm"), height -
                          grid::unit(1, "mm"), gp = grid::gpar(col = NA, fill = bg))
        grid::grid.rect(x, y, width - unit(0.5, "mm"), height -
                          unit(15, 'mm'), gp = grid::gpar(col = NA, fill = type_col['Amp']))
      } else if (any(type %in% 'Del')) {
        grid::grid.rect(x, y, width - unit(0.5, "mm"), height -
                          grid::unit(1, "mm"), gp = grid::gpar(col = NA, fill = bg))
        grid::grid.rect(x, y, width - unit(0.5, "mm"), height - grid::unit(15, "mm")
                        , gp = grid::gpar(col = NA, fill = type_col['Del']))
      }
    }
  }

  add_oncoprint2 = function(type, x, y, width, height) {
    for (i in 1:length(variant.classes)) {
      if (any(type %in% variant.classes[i])) {
        grid::grid.rect(x, y, width - unit(0.5, "mm"), height -
                          grid::unit(1, "mm"), gp = grid::gpar(col = NA, fill = type_col[variant.classes[i]]))
      } else if (any(type %in% 'Amp')) {
        grid::grid.rect(x, y, width - unit(0.5, "mm"), height -
                          unit(15, 'mm'), gp = grid::gpar(col = NA, fill = type_col['Amp']))
      } else if (any(type %in% 'Del')) {

        grid::grid.rect(x, y, width - unit(0.5, "mm"), height - grid::unit(15, "mm")
                        , gp = grid::gpar(col = NA, fill = type_col['Del']))
      }
    }
  }

  #This is the main cel function which is passed to ComplexHeatmap::Hetamap()
  celFun = function(j, i, x, y, width, height, fill) {
    type = mat[i, j]
    if(type != 'xxx'){
      typeList = unlist(strsplit(x = as.character(type), split = ';'))
      if(length(typeList) > 1){
        for(i in 1:length(typeList)){
          add_oncoprint2(typeList[i], x, y, width, height)
        }
      }else{
        for(i in 1:length(typeList)){
          add_oncoprint(typeList[i], x, y, width, height)
        }
      }

    }else{
      add_oncoprint(type, x, y, width, height)
    }
  }

  #----------------------------------------------------------------------------------------

  if(is.null(annotation)){
    ht = ComplexHeatmap::Heatmap(mat, rect_gp = grid::gpar(type = "none"), cell_fun = celFun,
                                row_names_gp = grid::gpar(fontsize = 10), show_column_names = showTumorSampleBarcodes,
                                show_heatmap_legend = FALSE, top_annotation_height = grid::unit(2, "cm"))
  }else{
    ht = ComplexHeatmap::Heatmap(mat, rect_gp = grid::gpar(type = "none"), cell_fun = celFun,
                                 row_names_gp = grid::gpar(fontsize = 10), show_column_names = showTumorSampleBarcodes,
                                 show_heatmap_legend = FALSE, top_annotation_height = grid::unit(2, "cm"),
                                 bottom_annotation = bot.anno)
  }

  legend = grid::legendGrob(labels = type_name[names(type_col)],  pch = 15, gp = grid::gpar(col = type_col), nrow = 2)

  ComplexHeatmap::draw(object = ht, newpage = FALSE, annotation_legend_side = "bottom", annotation_legend_list = list(legend))
}
