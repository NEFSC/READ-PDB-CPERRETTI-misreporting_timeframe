simulateAndFit <- function(noScaledYearsSim, sim_label){
  # Load NScod example to configure simulations
  load("./wg_MGWG/state-space/simData/fitNScod.Rdata")
  
  # Setup simulation scenarios
  simOut    <- vector("list", length = nrow(sim_label))
  setupMis  <- vector("list", length = nrow(sim_label))
  
  # Generate simulations
  for (i in 1:nrow(sim_label)) {
    simOut[[i]] <-
      sim(fit = fitNScod,
          noScaledYears = noScaledYearsSim,
          sim_label = sim_label[i,])
    
    # Prep simulation data for read.ices()
    prepSimData(simOut = simOut[[i]]) 
    
    # Load simulated data and setup SAM model configurations
    setupMis[[i]] <- setupModel(conf = fitNScod$conf,
                                stock_dir = "simData",
                                misreportingType = "rw",
                                noScaledYears = noScaledYearsFit)
  }
  
  # Fit model
  cl <- makeCluster(detectCores() - 1) #setup nodes for parallel
  #load stockassessment and functions to each node
  clusterEvalQ(cl, {library(stockassessment); source("loadFunctions.R")}) 
  
  # Estimate with misreporting as random effect
  fitMisSim <- parLapply(cl, setupMis, function(x){try(sam.fit_cp(x$dat, x$conf, x$par))})
  
  stopCluster(cl) #shut down nodes
  
  # Error handling
  ind2keep0 <- which(sapply(fitMisSim, class) != "try-error")
  # also exclude non-convergences
  ind2keep1 <- ind2keep0[unlist(sapply(fitMisSim[ind2keep0], 
                                       function (x) x[[6]][3])) != 1]
  
  ind2keep2 <- vector()
  for (i in ind2keep1) {
    if (mean(exp(fitMisSim[[i]]$pl$logN) / 
             exp(simOut[[i]]$trueParams$pl$logN)) < 1000) {
      ind2keep2 <- c(ind2keep2, i)
    }
  }
  
  simOutAccept    <- simOut[ind2keep2]
  setupMisAccept  <- setupMis[ind2keep2]
  fitMisSimAccept <- fitMisSim[ind2keep2]
  
  # Save fits and setups
  suffix <- paste0(Sys.Date(), ".Rdata")
  save(list = c("simOutAccept", 
                "setupMisAccept", 
                "fitMisSimAccept"), 
       file = paste0("./output/setupAndFits", suffix))
  
  return(list(simOutAccept = simOutAccept, 
              setupMisAccept = setupMisAccept,
              fitMisSimAccept = fitMisSimAccept))
}