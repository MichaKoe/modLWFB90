#' Soil-list creation
#'
#' This function is a wrapper of several functions and chunks of code and the main point of access for the final user. It takes a dataframe of coordinates of the points to be modeled and returns a list of soil data frames as required by \code{LWFBrook90R}. Adjustment options exist for the origin of soil data, the PTF to be used, whether MvG-parameters should be limited to a certain range, as well as all options for roots included in \code{\link[LWFBrook90R]{make_rootden}} and \code{\link{fnc_roots}} that can be passed down from here.
#'
#'
#' @param df.ids a data frame containing the following columns:
#' \itemize{
#' \item \code{ID_custom} - a unique ID-column for assignment that all intermediate products as well as the output will be assigned to.
#' \item \code{easting} and \code{northing} - coordinates in UTM EPSG:32632
#' } \cr OR: A simple feature with at the ID_custom-column. If df.ids is a simple feature, the polygon's centroids will be intersected with the Standortskartierung. A merging of information of partial coverage fractions of different STOK-polygons is not supported. So it is recommended to only use STOKA-Data as polygon-input layers, or to only use polygons that are small enough for the intersection process to not be an issue.
#' @param soil_option whether regionalised BZE, STOK Leitprofil data (\code{BZE}), or own data should be used for modelling. While option \code{BZE} with a buffer of 50 shouldn't create many NAs. \cr With option \code{OWN}, inusers can enter their own soil data (i.e. from lab or field experiments). If the option \code{OWN} is selected, the dataframes must be passed at \code{df.soils}.
#' @param add_BodenInfo shall further soil info (nFK, PWP, FK, texture ...) be added to the soil-df, default is \code{TRUE}
#' @param incl_GEOLA information from the \emph{Geowissenschaftliche Landesaufnahme} will be used to get additional data on soil depth and max root depth. On top of that,  \emph{Standortskartierung} and  \emph{GEOLA} will be used for identifying soil types that will be modelled differently to include the effect of groundwater (Gleye / Auenboeden) or alternating Saturation (Stauwasserboeden). Default is \code{TRUE}
#' @param parallel_processing the lists of dataframes are processed several times (adding roots, adding nFK information etc.). Default is \code{F} and runs with normal \code{lapply} statements. If many points are modelled, it is advised to set this to \code{T}, to activate parallel processing on several cores (as many as available). A BZE-based testrun with 32 GB RAM and 8 cores revealed a higher performance of parallel processing starting at the threshold of 250 points.
#' @param PTF_to_use the PTF to be used in the modeling process. Options are \code{HYPRES}, \code{PTFPUH2}, or \code{WESSOLEK}. Alternatively, if MvG parameters have been retrieved elsewhere (i.e. by lab analyses), \code{OWN_PARMS} can be selected to skip this.
#' @param limit_MvG should the hydraulic parameters limited to "reasonable" ranges as described in \code{\link{fnc_limit}}. Default is \code{FALSE}.
#' @param maxcores when using a computer with multiple cores and \code{parallel_processing = T}, too many busy cores will kill the process because it creates too much data for the RAM. For 32GB RAM a maximum of 30 cores are recommended (when no other applications are open).
#' @param limit_bodtief max soil depth, default is \code{NA} and uses max soil depth as defined in \code{df.LEIT}, \code{BZE} or the GEOLA-dataset. If not \code{NA}, soil-dfs are created down to the depth specified here as depth in \code{m}, negative
#' @param ... further function arguments to be passed down to \code{\link{fnc_roots}}. Includes all adjustment options to be found in \code{\link[LWFBrook90R]{make_rootden}}. \cr Only exception is the roots functions' parameter \code{maxrootdepth}, which, if desired, has to be specified here as  \code{roots_max}, because maximal root depth setting according to vegetation parameters will be complemented by root limitations from soil conditions. \cr Settings can be either single values, applied to all soil data frames equally, or vector with the same length as \code{df.ids} specifying the roots setting for each modelling point. see example. If roots are counted and provided in \code{df.soils} as column \code{rootden}, set to \code{table}.
#' @param bze_buffer whether buffer should be used in extracting points from BZE raster files if \code{NAs} occur in {m}, default is \code{12}, because that way only the closest of the 25m raster cells gets found and we don't get multiple points from the same cell
#' @param force_reg_rootsdepth there is a regionalised max-rootdepth, that takes into account certain soil conditions. However, it reduces the soil depth with roots significantly. Hence, by default, it is deactivated. If set to \code{T}, it will limit the lower roots depth to the regionalised values.
#' #' @param meta.out if \code{soil_option = "BZE"} and \code{bze_buffer != NA}, this is a way to save the meta-information of the buffering process. \code{meta.out} must be a path to a .csv-file, where for each point the coordinates and distance of the buffered cell will be stored.
#' @param df.soils if \code{OWN} is selected at soil_option, a data frame must be given here that contains the following columns
#' \itemize{
#' \item \code{ID} - a unique ID matching the IDs of df.ids
#' \item \code{mat} - number of soil layer starting with 1 counting upwards
#' \item \code{upper} and \code{lower} - upper and lower boundaries of soil layers in cm
#' \item \code{humus} - thickness of the humuslayer in m
#' \item \code{gravel} - gravel content in volumetric percent
#' \item \code{sand} - optional - sand content in volumetric percent
#' \item \code{silt} - optional - silt content in volumetric percent
#' \item \code{clay} - optional - clay content in volumetric percent
#' \item \code{texture} - optional either texture or sand/silt/clay - texture
#'
#' }
#' Caution:\cr
#' If PTFs are to be applied, the columns required in \code{\link{fnc_PTF}} must be provided. Else, if \code{PTF_to_use} is set to \code{OWN_PARMS}, the following columns must be provided NA-free: \code{ths, thr, alpha, npar, mpar, ksat}, and \code{tort}.\cr
#' If roots are to be calculated, the columns required in \code{\link{fnc_roots}} must be provided. Otherwise they need to be stored in a column called \code{rootden}.\cr
#' If the nFK shall be calculated at some point, this will be done for the first 1m depth, so in this case one of the layers should end at 100cm depth.
#'
#' @return Returns a list of soil data frames completely processed to be further used by \code{\link[LWFBrook90R]{run_multisite_LWFB90}} or \code{\link[LWFBrook90R]{run_LWFB90}}
#'
#'
#' @example inst/examples/fnc_get_soil_ex.R
#' @export

# df.ids <- st_read("J:/FVA-Projekte/P01765_StWM_KPW/Daten/Urdaten/GIS/Exkursionsgebiet/Stoka.shp")[1:5,] %>%
#   mutate(ID_custom = paste0("ID_0", 1:nrow(.))) %>% select(ID_custom)
#
fnc_get_soil <- function(df.ids,
                         soil_option,
                         PTF_to_use,

                         df.soils = NULL,

                         limit_MvG = T,
                         add_BodenInfo = T,
                         incl_GEOLA = T,
                         parallel_processing = F,

                         bze_buffer = 12,
                         meta.out = NA,
                         limit_bodtief = NA,
                         force_reg_rootsdepth = F,
                         maxcores = NA,

                         ...

                         ){


  if(parallel_processing & is.na(maxcores)){
    maxcores = parallel::detectCores()-1
  }

  argg <- c(as.list(environment()), list(...))
  `%dopar%` <- foreach::`%dopar%`
  data(paths)

  # sort dfs according to IDs
  df.ids$ID <- 1:nrow(df.ids)
  npoints <- nrow(df.ids)

  # transformation of ids to GK3 for slope & aspect ---------- ####

  # calculation of centroids or points on surface:
  if(all(c("sf", "data.frame") %in% class(df.ids))){
    df.ids <- sf::st_transform(df.ids, 32632)

    sf_cent <- sf::st_centroid(df.ids[,c("ID", "ID_custom")]) %>%
      sf::st_transform(32632) %>%
      dplyr::mutate(easting = round(st_coordinates(.)[, "X"]),
                    northing = round(st_coordinates(.)[, "Y"]))

    cents_on_polys <- sf::st_intersection(sf_cent, df.ids) %>%
      dplyr::filter(ID == ID.1) %>% pull(ID)

    sf_points <- sf::st_point_on_surface(df.ids[,c("ID", "ID_custom")]) %>%
      sf::st_transform(32632) %>%
      dplyr::filter(!ID %in% cents_on_polys)
    if(nrow(sf_points) > 0){
      sf_points <- sf_points %>%
        dplyr::mutate(easting = round(st_coordinates(.)[, "X"]),
                      northing = round(st_coordinates(.)[, "Y"]))
    }

    df.ids <- sf_cent %>%
      dplyr::filter(ID %in% cents_on_polys) %>%
      dplyr::bind_rows(., sf_points) %>% dplyr::arrange(ID) %>% sf::st_drop_geometry()
  }

  df.dgm <- sf::st_as_sf(df.ids,
                         coords = c("easting", "northing"), crs = 32632) %>%
    sf::st_transform(25832)
  df.dgm <- terra::vect(df.dgm)
  dgm_spat <- terra::rast(list.files(path_DGM, pattern = "aspect.tif$|slope.tif$", full.names=T))
  df.dgm <- round(terra::extract(dgm_spat, df.dgm), 0)


  # choice of data origin:  ---------------------------------- ####
  cat("Gathering soil data...\n")
  if (soil_option == "STOK") {

    # load df.LEIT
    df.LEIT.BW <- readRDS(path_df.LEIT)

    df.ids <- dplyr::left_join(df.ids, df.dgm, by = "ID")

      # create sf
      sf.ids <- sf::st_as_sf(df.ids[,c("ID", "ID_custom", "aspect","slope","easting", "northing")],
                             coords = c("easting", "northing"), crs = 32632)

      # check which wuchsgebiete are needed
      sf.wugeb <- sf::st_read(paste0(path_WGB_diss_shp, "wugebs.shp"), quiet = T)

      wugeb <- sort(paste0(unique(unlist(sf::st_intersects(sf.ids,
                                                           sf.wugeb),
                                         recursive = F)), ".shp"),
                    decreasing = F)

      if(length(wugeb) > 4 ){
        #Read required GEOLA and STOKA shapefiles
        cl <- parallel::makeCluster(ifelse(length(wugeb) < parallel::detectCores(),
                                           length(wugeb),
                                           parallel::detectCores()))
        doParallel::registerDoParallel(cl)

        sf.geola <- foreach::foreach(i = wugeb,
                                     .packages = "sf",
                                     .combine = rbind) %dopar% {
                                       sf::st_read(paste0(path_GEOLA_pieces, i),
                                                   quiet = T)
                                     }
        sf.stoka <- foreach::foreach(i = wugeb,
                                     .packages = "sf",
                                     .combine = rbind) %dopar% {
                                       sf::st_read(paste0(path_STOK_pieces, i),
                                                   quiet = T)
                                     }

        parallel::stopCluster(cl)
      }else{
        for(i in wugeb){

          stoka.tmp <- sf::st_read(paste0(path_STOK_pieces, i),
                                   quiet = T)

          if(i == wugeb[1]){sf.stoka <- stoka.tmp}else{sf.stoka <- rbind(sf.stoka, stoka.tmp)}

          geola.tmp <- sf::st_read(paste0(path_GEOLA_pieces, i),
                                   quiet = T)

          if(i == wugeb[1]){sf.geola <- geola.tmp}else{sf.geola <- rbind(sf.geola, geola.tmp)}

        }
        rm(list = c("stoka.tmp", "geola.tmp"))
      }


      sf.ids <-  sf.ids %>%
        sf::st_join(sf.geola) %>%
        sf::st_join(sf.stoka) %>%

        sf::st_drop_geometry() %>%
        dplyr::distinct() %>%
        dplyr::mutate(GRUND_C = as.numeric(GRUND_C),
                      BODENTY = case_when(str_detect(BODENTY, "Moor") & !str_detect(FMO_KU, "vermoort") ~ "sonstige",
                                          str_detect(WHH_brd, "G") ~ "Gleye/Auenboeden",
                                          str_detect(WHH_brd, "S") ~ "Stauwasserboeden",
                                          str_detect(BODENTY, "Gleye/Auenboeden") & !str_detect(WHH_brd, "G") ~ "sonstige",
                                          str_detect(BODENTY, "Stauwasserboeden") & !str_detect(WHH_brd, "S") ~ "sonstige",
                                          T ~ BODENTY),
                      humus = hmsmcht/100,
                      RST_F = as.character(RST_F)) %>%
        # Swamps - via FMO_KU of STOKA
        dplyr::filter(FMO_KU != "vermoort") %>%
        dplyr::select(any_of(c("ID", "ID_custom", "aspect", "slope", "GRUND_C", "BODENTY", "RST_F", "WugebNr", "humus")))


      df.ids <- dplyr::left_join(df.ids, sf.ids)

      # remove missing RST_F in df.LEIT
      RST_miss <- unique(sf.ids$RST_F[!sf.ids$RST_F %in% df.LEIT.BW$RST_F])

      # clear up space
      rm(list = c("sf.geola", "sf.wugeb", "sf.stoka")); gc()

      IDs_miss <- df.ids$ID[(is.na(df.ids$RST_F) | df.ids$RST_F %in% RST_miss)] # remove non-forest-rst_fs
      IDs_good <- df.ids$ID[!df.ids$ID %in% IDs_miss] # IDs good

      # all IDs mapped by STOKA
      if(length(IDs_miss) == 0){

        ls.soils <- fnc_soil_stok(df = df.ids,
                                  df.LEIT = df.LEIT.BW,
                                  PTF_to_use = PTF_to_use,
                                  limit_bodtief = limit_bodtief,
                                  incl_GEOLA = incl_GEOLA,
                                  parallel_processing = parallel_processing)
        if(length(ls.soils) == 0){
          stop("none of the given points has STOKA data")
        }

        bodentypen <- unlist(lapply(ls.soils, function(x) unique(x$BODENTYP)))
        dpth_lim_soil <- unlist(lapply(ls.soils, function(x) unique(x$dpth_ini)))

      } else {

        message(paste0("ID: ", as.character(as.data.frame(df.ids)[IDs_miss, "ID_custom"]),
                       " won't be modelled. There's no complete STOK data available. \n"))

          sf.ids <- sf.ids[-IDs_miss,] # remove missing IDs
          ls.soils <- fnc_soil_stok(df = sf.ids,
                                    df.LEIT = df.LEIT.BW,
                                    PTF_to_use = PTF_to_use,
                                    limit_bodtief = limit_bodtief,
                                    incl_GEOLA = incl_GEOLA,
                                    parallel_processing = parallel_processing)
          if(length(ls.soils) == 0){
            stop("none of the given points has STOKA data")
          }

          bodentypen <- unlist(lapply(ls.soils, function(x) unique(x$BODENTYP)))
          dpth_lim_soil <- unlist(lapply(ls.soils, function(x) unique(x$dpth_ini)))

    }

  } else if (soil_option == "BZE") {

    df.ids <- dplyr::left_join( df.ids, df.dgm, by = "ID")

    # create sf
    sf.ids <- sf::st_as_sf(df.ids[,c("ID", "ID_custom", "aspect","slope","easting", "northing")],
                           coords = c("easting", "northing"), crs = 32632)

    # check which wuchsgebiete are needed
    sf.wugeb <- sf::st_read(paste0(path_WGB_diss_shp, "wugebs.shp"), quiet = T)

    wugeb <- sort(paste0(unique(unlist(sf::st_intersects(sf.ids,
                                                         sf.wugeb),
                                       recursive = F)), ".shp"),
                  decreasing = F)

    if(length(wugeb) > 4 ){
      #Read required GEOLA and STOKA shapefiles
      cl <- parallel::makeCluster(ifelse(length(wugeb) < parallel::detectCores(),
                                         length(wugeb),
                                         parallel::detectCores()))
      doParallel::registerDoParallel(cl)

      sf.geola <- foreach::foreach(i = wugeb,
                                   .packages = "sf",
                                   .combine = rbind) %dopar% {
                                     sf::st_read(paste0(path_GEOLA_pieces, i),
                                                 quiet = T)
                                   }
      sf.stoka <- foreach::foreach(i = wugeb,
                                   .packages = "sf",
                                   .combine = rbind) %dopar% {
                                     sf::st_read(paste0(path_STOK_pieces, i),
                                                 quiet = T)
                                   }

      parallel::stopCluster(cl)
    }else{
      for(i in wugeb){

        stoka.tmp <- sf::st_read(paste0(path_STOK_pieces, i),
                                 quiet = T)

        if(i == wugeb[1]){sf.stoka <- stoka.tmp}else{sf.stoka <- rbind(sf.stoka, stoka.tmp)}

        geola.tmp <- sf::st_read(paste0(path_GEOLA_pieces, i),
                                 quiet = T)

        if(i == wugeb[1]){sf.geola <- geola.tmp}else{sf.geola <- rbind(sf.geola, geola.tmp)}

      }
      rm(list = c("stoka.tmp", "geola.tmp"))
    }


    sf.ids <-  sf.ids %>%
      sf::st_join(sf.geola) %>%
      sf::st_join(sf.stoka) %>%

      sf::st_drop_geometry() %>%
      dplyr::distinct() %>%
      dplyr::mutate(GRUND_C = as.numeric(GRUND_C),
                    BODENTY = case_when(str_detect(BODENTY, "Moor") & !str_detect(FMO_KU, "vermoort") ~ "sonstige",
                                        str_detect(WHH_brd, "G") ~ "Gleye/Auenboeden",
                                        str_detect(WHH_brd, "S") ~ "Stauwasserboeden",
                                        str_detect(BODENTY, "Gleye/Auenboeden") & !str_detect(WHH_brd, "G") ~ "sonstige",
                                        str_detect(BODENTY, "Stauwasserboeden") & !str_detect(WHH_brd, "S") ~ "sonstige",
                                        T ~ BODENTY),
                    humus = hmsmcht/100,
                    RST_F = as.character(RST_F)) %>%
      # Swamps - via FMO_KU of STOKA
      dplyr::filter(FMO_KU != "vermoort") %>%
      dplyr::select(any_of(c("ID", "ID_custom", "aspect", "slope", "GRUND_C", "BODENTY", "RST_F", "WugebNr")))


    df.ids <- dplyr::left_join(df.ids, sf.ids)

    cat("starting BZE extraction...\n")
    ls.soils <- fnc_soil_bze(df.ids = df.ids[,c("ID_custom", "ID","easting","northing", "BODENTY", "aspect", "slope", "GRUND_C", "WugebNr")],
                             buffering = (!is.na(bze_buffer)),
                             buff_width = bze_buffer,

                             limit_bodtief = limit_bodtief,
                             meta.out = meta.out,
                             incl_GEOLA = incl_GEOLA)

    all.nas <- which(! df.ids$ID_custom %in% names(ls.soils) )

    bodentypen <- unlist(lapply(ls.soils, function(x) unique(x$BODENTYP)))
    dpth_lim_soil <- unlist(lapply(ls.soils, function(x) unique(x$dpth_ini)))

  } else if (soil_option == "OWN") {

    if(!all(df.ids$ID_custom == unique(df.soils$ID_custom))){
      stop("\n not all ID_custom of df.ids and df.soils are equal")
    } else {

      ls.soils <- df.soils %>%
        dplyr::left_join(df.ids) %>%
        dplyr::arrange(ID, mat, -upper) %>%
        dplyr::select(ID, ID_custom, everything()) %>%
        dplyr::group_split(ID)

      if(parallel_processing){

        cl <- parallel::makeCluster(parallel::detectCores())
        doParallel::registerDoParallel(cl)
        ls.soils <- foreach::foreach(i = 1:length(ls.soils),
                                     .packages = c("modLWFB90","dplyr"),
                                     .export = c("df.dgm")) %dopar% {
                                       x <- fnc_depth_disc(ls.soils[[i]],
                                                           limit_bodtief = limit_bodtief)

                                       if(!all(c("slope", "aspect") %in% colnames(x))){
                                         x <- dplyr::left_join(x = x, y = df.dgm, by = "ID")
                                       }

                                       x <- x %>%
                                         dplyr::mutate(dplyr::across(c("upper", "lower"),
                                                                     ~ . /-100),
                                                       gravel = gravel/100) %>%
                                         dplyr::mutate(nl = 1:n(), .after = ID_custom)

                                     }
        parallel::stopCluster(cl)

      }else{

        ls.soils <- lapply(ls.soils, FUN = fnc_depth_disc, limit_bodtief = limit_bodtief)

        if(!all(c("slope", "aspect") %in% colnames(df.ids))){
          ls.soils <- lapply(ls.soils, FUN = dplyr::left_join, y = df.dgm, by = "ID")
        }

        ls.soils <- lapply(ls.soils, FUN = function(x){
          x %>%
            dplyr::mutate(dplyr::across(c("upper", "lower"),
                                        ~ . /-100),
                          gravel = gravel/100) %>%
            dplyr::mutate(nl = 1:n(), .after = ID_custom)})

      }

      names(ls.soils) <- df.ids$ID_custom
    }

  } else {
    stop("\nPlease provide valid soil-option")
  }


  # PTF-application: ----------------------------------------- ####
  cat("Applying PTFs / own MvG parameters...\n")
  if(PTF_to_use == "OWN_PARMS"){

    # check if all necessary columns are there:
    missingcol <- c("ths", "thr", "alpha", "npar",
                    "mpar", "ksat", "tort")[!c("ths", "thr", "alpha", "npar",
                                               "mpar", "ksat", "tort") %in% names(df.soils)]
    if (length(missingcol) > 0){
      cat("\n", missingcol, "is missing")
      stop("missing columns")
    }else{
      ls.soils <- lapply(ls.soils, FUN = function(x){
        if("humus" %in% colnames(x)){
          humus <- x$humus[1]
          df <- x[0,]
          df[1,] <- NA
          df$mat <- 0; df$ID <- unique(x$ID); df$ID_custom <- unique(x$ID_custom);
          df$gravel <- 0; df$ths <- 0.848; df$thr <- 0; df$alpha <- 98; df$npar <- 1.191; df$mpar <- 0.160;
          df$ksat <- 98000; df$tort <- 0.5; df$upper <- humus; df$lower <- 0

          x <- rbind(df, x)
          for(i in 1:ncol(x)){
            if(is.na(x[1,i])){x[1,i] <- x[2,i]}
          }
          x <- x[,-which(colnames(x) == "humus")]
          x$nl <- 1:nrow(x)

        }
        return(x)
      })
    }


  } else {

    if(parallel_processing){
      cl <- parallel::makeCluster(maxcores)
      doParallel::registerDoParallel(cl)
      ls.soils <- foreach::foreach(i = 1:length(ls.soils),
                                   .packages = "modLWFB90") %dopar% {
                                     x <- fnc_PTF(ls.soils[[i]], PTF_used = PTF_to_use)
                                   }
      parallel::stopCluster(cl)
    }else{
      ls.soils <- lapply(ls.soils,
                         FUN = fnc_PTF,
                         PTF_used = PTF_to_use)
    }

  }

  # for(i in 1:length(ls.soils)){
  #   x <- modLWFB90::fnc_PTF(ls.soils[[i]],
  #                           PTF_used = PTF_to_use)
  #   print(x)
  # }
  # MvG-limitation if desired: ------------------------------- ####
  if(limit_MvG){


    if(parallel_processing){
      cl <- parallel::makeCluster(maxcores)
      doParallel::registerDoParallel(cl)
      ls.soils <- foreach::foreach(i = 1:length(ls.soils),
                                   .packages = c("modLWFB90")) %dopar% {
                                     x <- modLWFB90:::fnc_limit(ls.soils[[i]])
                                   }
      parallel::stopCluster(cl)
    }else{
      ls.soils <- lapply(ls.soils, modLWFB90:::fnc_limit)
    }


  }

  # Roots: --------------------------------------------------- ####
  cat("Calculating roots...\n")

  if(soil_option != "OWN"){

    # roots limited by soil conditions and/or vegetation parameters
    if(any(stringr::str_detect(names(argg), "roots_max"))){

      roots_max <- argg[[which(names(argg) == "roots_max")]]
      roots_max_cm <- roots_max*-100

      if(length(roots_max) == 1){
        dpth_lim_veg <- rep(roots_max_cm, length(ls.soils))
      }else{

        if(npoints != length(roots_max)){
          stop("Number of points and length of maxdepth-vector not the same.")
        }

        if(length(all.nas) != 0){
          dpth_lim_veg <- roots_max_cm[!all.nas]
        }else{
          dpth_lim_veg <- roots_max_cm
        }
      }

      if((soil_option == "BZE" & force_reg_rootsdepth == T)|
         soil_option == "STOK"){
        maxdepth <- pmin(dpth_lim_soil, dpth_lim_veg, na.rm = T)/-100
      }else{
        maxdepth <- dpth_lim_veg/-100
      }

    } else {

      if((soil_option == "BZE" & force_reg_rootsdepth == T)|
         soil_option == "STOK"){
        maxdepth <- dpth_lim_soil/-100
      }else{
        maxdepth <- sapply(ls.soils, function(x){min(x$lower)})
      }

    }


    ls.soils <- mapply(FUN = fnc_roots,
                       ls.soils,

                       roots_max_adj = maxdepth,
                       # beta = 0.976,
                       # rootsmethod = "betamodel",
                       # # maxrootdepth = c(-1,-1.5,-0.5, -1.5,-2),

                       ...,

                       SIMPLIFY = F)

  }else{
    if(any(stringr::str_detect(names(argg), "roots_max"))){
      roots_max <- argg[[which(names(argg) == "roots_max")]]
      ls.soils <- mapply(FUN = fnc_roots,
                         ls.soils,

                         # rootsmethod = "betamodel",
                         # beta = 0.97,
                         roots_max_adj = roots_max,
                         # # maxrootdepth = c(-1,-1.5,-0.5, -1.5,-2),
                         # beta = vec.beta,
                         ...,

                         SIMPLIFY = F)

    } else {
      ls.soils <- mapply(FUN = fnc_roots,
                         ls.soils,

                         # rootsmethod = "betamodel",
                         # beta = 0.97,
                         # maxrootdepth = -2,
                         # # maxrootdepth = c(-1,-1.5,-0.5, -1.5,-2),

                         ...,

                         SIMPLIFY = F)
    }

  }


  # GEOLA application ---------------------------------------- ####
  if(incl_GEOLA){
    cat("Applying STOK and GEOLA...\n")

    if(parallel_processing){
      cl <- parallel::makeCluster(maxcores)
      doParallel::registerDoParallel(cl)

      ls.soils <- foreach::foreach(i = 1:length(ls.soils),
                                   .packages = c("dplyr", "LWFBrook90R")) %dopar% {

                                     x <- ls.soils[[i]]

                                     if(soil_option == "STOK"){
                                       x$soiltype <- bodentypen[i]
                                       if(!is.na(bodentypen[i]) & bodentypen[i] == "Gleye/Auenboeden"){
                                         x[c(nrow(x)-1, nrow(x)), "ksat"] <- 0.0001
                                       }
                                     }

                                     if(soil_option == "BZE"){

                                       if(!is.na(bodentypen[i]) & bodentypen[i] == "Stauwasserboeden"){
                                         mvg <- LWFBrook90R::hydpar_hypres(clay = 30, silt = 70, bd = 2, topsoil = F)
                                         mvg$ksat <- dplyr::case_when(x$WugebNr[1] %in% c(5) ~ 90,
                                                               x$WugebNr[1] %in% c(2) ~ 2,
                                                               x$WugebNr[1] %in% c(3,4,6) ~ 5,
                                                               x$WugebNr[1] %in% c(1) ~ 1,
                                                               x$WugebNr[1] %in% c(7) ~ 7,
                                                               T~10) # Aus Sd-Definition in der KA5
                                         n_rep <- 3 #

                                         lastrow <- subset(x, nl == max(nl))

                                         #df.sd erstellen (letzte Zeile von df.soil, um Bodeninfo zu uebernehmen)
                                         df.sd <- as.data.frame(lapply(lastrow, rep, n_rep))

                                         # Veraenderliche Spalten aendern
                                         if("rootden" %in% colnames(x)){
                                           df.sd <- df.sd %>% dplyr::mutate(rootden = 0)
                                         }
                                         df.sd <- df.sd %>%
                                           dplyr::mutate(mat = mat + 1,
                                                         nl = nl + c(1: n_rep),
                                                         lower = lastrow$lower + c(-0.1, -0.2, -0.3),
                                                         upper = lastrow$lower + c(0, -0.1, -0.2),
                                                         sand = 0,
                                                         silt = 70,
                                                         clay = 30,
                                                         bd = 2,

                                                         #MvG-Parameter Ls2 fuer Stauhorizont
                                                         ths = mvg$ths,
                                                         thr = mvg$thr,
                                                         alpha = mvg$alpha,
                                                         npar = mvg$npar,
                                                         mpar = mvg$mpar,
                                                         tort = mvg$tort,
                                                         ksat = mvg$ksat) %>%
                                           dplyr::relocate(names(lastrow))

                                         # df.stau an df.soils anfuegen
                                         x <- rbind(x, df.sd)
                                         x$soiltype <- bodentypen[i]

                                       } else if(!is.na(bodentypen[i]) & bodentypen[i] == "Gleye/Auenboeden"){
                                         # stop water from leaving horizon below 2.60
                                         x$mat[tail(x$nl, 2)] <- max(x$mat)+1
                                         x$ksat[tail(x$nl, 2)] <- 0.0001
                                         x$rootden[tail(x$nl, 2)] <- 0
                                         x$soiltype <- bodentypen[i]

                                         if(any(x$npar < 1.1)){
                                           x <- x %>%
                                             mutate(npar = dplyr::case_when(npar < 1.1 ~ 1.1,
                                                                            T~npar),
                                                    mpar = 1-1/npar)
                                         }

                                       }else{
                                         x$soiltype <- bodentypen[i]
                                       }
                                     }
                                     x <- x
                                   }

      parallel::stopCluster(cl)
    }else{
      if(soil_option == "STOK"){

        ls.soils <- mapply(FUN = function(x, bodentyp){
          x$soiltype <- bodentyp
          if(!is.na(bodentyp) & bodentyp == "Gleye/Auenboeden"){
            x[c(nrow(x)-1, nrow(x)), "ksat"] <- 0.0001
          }
          return(x)
        },
        ls.soils,
        bodentypen,
        SIMPLIFY = F)
      }
      if(soil_option == "BZE"){

        ls.soils <- mapply(FUN = function(x, bodentyp){
          if(!is.na(bodentyp) & bodentyp == "Stauwasserboeden"){
            mvg <- hydpar_hypres(clay = 30, silt = 70, bd = 2, topsoil = F)
            mvg$ksat <- dplyr::case_when(x$WugebNr[1] %in% c(5) ~ 90,
                                         x$WugebNr[1] %in% c(2) ~ 2,
                                         x$WugebNr[1] %in% c(3,4,6) ~ 5,
                                         x$WugebNr[1] %in% c(1) ~ 1,
                                         x$WugebNr[1] %in% c(7) ~ 7,
                                         T~10)# Aus Sd-Definition in der KA5
            n_rep <- 3 #

            lastrow <- subset(x, nl == max(nl))

            #df.sd erstellen (letzte Zeile von df.soil, um Bodeninfo zu uebernehmen)
            df.sd <- as.data.frame(lapply(lastrow, rep, n_rep))

            # Veraenderliche Spalten aendern
            if("rootden" %in% colnames(x)){
              df.sd <- df.sd %>% mutate(rootden = 0)
            }
            df.sd <- df.sd %>%
              mutate(mat = mat + 1,
                     nl = nl + c(1: n_rep),
                     lower = lastrow$lower + c(-0.1, -0.2, -0.3),
                     upper = lastrow$lower + c(0, -0.1, -0.2),
                     sand = 0,
                     silt = 70,
                     clay = 30,
                     bd = 2,

                     #MvG-Parameter Ls2 fuer Stauhorizont
                     ths = mvg$ths,
                     thr = mvg$thr,
                     alpha = mvg$alpha,
                     npar = mvg$npar,
                     mpar = mvg$mpar,
                     tort = mvg$tort,
                     ksat = mvg$ksat) %>%
              relocate(names(lastrow))

            # df.stau an df.soils anfuegen
            x <-   rbind(x, df.sd)
            x$soiltype <- bodentyp
            return(x)
          } else if(!is.na(bodentyp) & bodentyp == "Gleye/Auenboeden"){
            # stop water from leaving horizon below 2.60
            x$mat[tail(x$nl, 2)] <- max(x$mat)+1
            x$ksat[tail(x$nl, 2)] <- 0.0001
            x$rootden[tail(x$nl, 2)] <- 0
            x$soiltype <- bodentyp

            return(x)
          }else{
            x$soiltype <- bodentyp
            return(x)
          }
        },
        ls.soils,
        bodentyp = bodentypen,
        SIMPLIFY = F)
      }
    }
  }



  # add_BodenInfo: ------------------------------------------- ####

  if(add_BodenInfo){
    cat("Adding soil info...\n")

    if(parallel_processing){
      cl <- parallel::makeCluster(maxcores)
      doParallel::registerDoParallel(cl)

      ls.soils <- foreach::foreach(i = 1:length(ls.soils),
                                   .packages = c("modLWFB90", "data.table")) %dopar% {
                                     x <- modLWFB90::fnc_add_nFK(ls.soils[[i]])
                                   }

      parallel::stopCluster(cl)
    }else{
      ls.soils <- lapply(ls.soils, fnc_add_nFK)
    }

  }


  # reduce --------------------------------------------------- ####
  to_2 <- c("sand", "silt","clay", "oc.pct",  "tort")
  to_3 <- c("gravel", "bd", "ths", "thr", "alpha", "npar", "mpar", "rootden" )
  cat("almost done...\n\n")

  if(parallel_processing){
    cl <- parallel::makeCluster(maxcores)
    doParallel::registerDoParallel(cl)

    ls.soils <- foreach::foreach(i = 1:length(ls.soils),
                                 .packages = c("dplyr")) %dopar% {

                                   x <- ls.soils[[i]] %>%
                                     dplyr::mutate(dplyr::across(dplyr::any_of(to_2), ~round(.x,2)),
                                                   dplyr::across(dplyr::any_of(to_3), ~round(.x,3)))

                                 }

    parallel::stopCluster(cl)
  }else{
    ls.soils <- lapply(ls.soils,
                       FUN = function(x){
                         x <- x %>%
                           dplyr::mutate(across(any_of(to_2), ~round(.x, 2)),
                                         across(any_of(to_3), ~round(.x, 3)))
                       })
  }

  names(ls.soils) <- unlist(lapply(ls.soils, function(x) unique(x$ID_custom)))

  return(ls.soils)
}

