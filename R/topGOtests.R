#' @name Gene set tests statistics
#' @rdname GOTests
#' @title Gene set tests statistics
#' @aliases GOFisherTest GOKSTest GOKS2Test GOtTest GOglobalTest GOSumTest GOKSTiesTest permSumStats permSumStats.all
#' @description Methods which implement and run a group test statistic for
#'   a class inheriting from \code{groupStats} class. See Details section
#'   for a description of each method.
#' 
#' @usage
#' GOFisherTest(object)
#' GOKSTest(object)
#' GOKS2Test(object)
#' GOtTest(object)
#' GOglobalTest(object)
#' GOSumTest(object)
#' GOKSTiesTest(object)
#' 
#'@param object An object of class \code{groupStats} or decedent class.
#' 
#' 
#' @details
#'   GOFisherTest: implements Fischer's exact test (based on contingency
#'   table) for \code{groupStats} objects dealing with "counts".
#'   
#'   GOKSTest: implements the Kolmogorov-Smirnov test for \code{groupStats}
#'   objects dealing with gene "scores". This test uses the \code{ks.test}
#'   function and does not implement the running-sum-statistic test based
#'   on permutations. 
#' 
#'   GOtTest: implements the t-test for \code{groupStats} objects dealing
#'   with gene "scores". It should be used when the gene scores are
#'   t-statistics or any other score following a normal distribution.
#'     
#'   GOglobalTest: implement Goeman's globaltest.
#' 
#' @return All these methods return the p-value computed by the respective test statistic.
#' 
#' @author Adrian Alexa
#' 
#' @examples
#' data(ONTdata)
#' gene.universe <- genes(GOdata)
#' go.genes <- genesInTerm(GOdata, 'DOID:0050709')[[1]]
#' sig.genes <- sigGenes(GOdata)
#' my.group <- new("classicCount", testStatistic = GOFisherTest, name = "fisher",allMembers = gene.universe, groupMembers = go.genes,sigMembers = sig.genes)
#' contTable(my.group)
#' runTest(my.group)
#' 
#' @seealso
#'   \code{\link{groupStats-class}},
#'   \code{\link{getSigGroups-methods}}
#' @keywords misc
NULL

## put here all tests statistic

if(!isGeneric("GOFisherTest"))
  setGeneric("GOFisherTest", function(object) standardGeneric("GOFisherTest"))
                               
setMethod("GOFisherTest", "classicCount",
          function(object) {

            contMat <- contTable(object)
            
            if(all(contMat == 0))
              p.value <- 1
            else
              p.value <- fisher.test(contMat, alternative = 'greater')$p.value

            return(p.value)
          })



if(!isGeneric("GOKSTest"))
  setGeneric("GOKSTest", function(object) standardGeneric("GOKSTest"))
                               
setMethod("GOKSTest", "classicScore",
          function(object) {

            N <- numAllMembers(object)
            na <- numMembers(object)

            ## if the group is empty ... (should not happen, but you never know!)
            if(na == 0 || na == N)
              return(1)

            x.a <- rankMembers(object)
            ## x.b <- setdiff(1:N, x.a)
            
            return(ks.test(x.a, seq_len(N)[-x.a], alternative = "greater")$p.value)
          })

if(!isGeneric("GOKS2Test"))
  setGeneric("GOKS2Test", function(object) standardGeneric("GOKS2Test"))

setMethod("GOKS2Test", "classicScore",
          function(object) {
            
            N <- numAllMembers(object)
            na <- numMembers(object)
            
            ## if the group is empty ... (should not happen, but you never know!)
            if(na == 0 || na == N)
              return(1)
            
            x.a <- rankMembers(object)
            ## x.b <- setdiff(1:N, x.a)
            goks2 <- ks.test.2(x.a, seq_len(N)[-x.a])
#            sign_i <- sign(goks2$ES)
            
            return(sign(goks2$ES) * goks2$p.value)
            
          })


if(!isGeneric("GOtTest"))
  setGeneric("GOtTest", function(object) standardGeneric("GOtTest"))
                               
setMethod("GOtTest", "classicScore",
          function(object) {

            ## we should try to do this smarter!!! 
            var.equal <- FALSE
            ## check if there are any parameters set
            if(length(testStatPar(object)) != 0)
              if("var.equal" %in% names(testStatPar(object)))
                var.equal <- testStatPar(object)[["var.equal"]]
                                        
            nG <- numMembers(object)
            nNotG <- numAllMembers(object) - nG
            
            ## if the group/complementary is empty 
            if(nNotG == 0 || nG == 0)
              return(1)

            x.G <- membersScore(object)
            x.NotG <- allScore(object, TRUE)[setdiff(allMembers(object), members(object))]

            aa <- scoreOrder(object)
            ## alternative - TRUE if the max(score) is the best score), FALSE if the min(score)...
            if(nNotG == 1) {
              .stat <- ifelse(aa, sum(x.G >= x.NotG), sum(x.G <= x.NotG))
              p.value <- (.stat + 1) / (nG + nNotG + 1)
            }
            else if(nG == 1) {
              .stat <- ifelse(aa, sum(x.NotG >= x.G), sum(x.NotG <= x.G))
              p.value <- (.stat + 1) / (nG + nNotG + 1)
            }
            else 
              p.value <- t.test(x = x.G, y = x.NotG, var.equal = var.equal,
                                alternative = ifelse(aa, "greater", "less"))$p.value
            
            return(p.value)
          })



if(!isGeneric("GOglobalTest"))
  setGeneric("GOglobalTest", function(object) standardGeneric("GOglobalTest"))
                               
setMethod("GOglobalTest", "classicExpr",
          function(object) {
            
            if(numMembers(object) == 0)
              return(1)

            return(globaltest::p.value(globaltest::gt(X = membersExpr(object), Y = pType(object))))
          })


permSumStats <- function(object, N) {

  ## the gene scores
  scoreVec <- geneScore(object)
  sizeLookUp <- integer(length(scoreVec))

  ## the available GOs and their size
  goSize <- sort(unique(countGenesInTerm(object)))
  
  ## remove the GO sizes which are 60% or more of the max size
  goSize <- goSize[goSize / max(goSize) < .6]
  maxSample <- goSize[length(goSize)]

  ## update the look-up table with the feasible sizes
  sizeLookUp[goSize] <- 1:length(goSize)

  assign(".PERMSUM.LOOKUP", sizeLookUp, .GlobalEnv)
  assign(".PERMSUM.MAT", sapply(1:N, function(x) cumsum(sample(scoreVec, maxSample))[goSize]), .GlobalEnv)
}

## same as above just doesn't remove any term 
permSumStats.all <- function(object, N) {

  ## the gene scores
  scoreVec <- geneScore(object)
  sizeLookUp <- integer(length(scoreVec))

  ## the available GOs and their size
  goSize <- sort(unique(countGenesInTerm(object)))

  ## update the look-up table with the feasible sizes
  sizeLookUp[goSize] <- 1:length(goSize)

  assign(".PERMSUM.LOOKUP", sizeLookUp, .GlobalEnv)
  assign(".PERMSUM.MAT", sapply(1:N, function(x) cumsum(sample(scoreVec))[goSize]), .GlobalEnv)
}


## Category test based on score sums 
if(!isGeneric("GOSumTest"))
  setGeneric("GOSumTest", function(object) standardGeneric("GOSumTest"))
                               
setMethod("GOSumTest", "classicScore",
          function(object) {

            nG <- numMembers(object)
            if(nG == 0) return(1)
            N <- ncol(get(".PERMSUM.MAT",.GlobalEnv))
            
            ## compute the group sum (statistic)
            sObserved <- sum(membersScore(object))
            
            ## check to see if we have a precomputed the permutations for this group size
            isPermuted <- get(".PERMSUM.LOOKUP",.GlobalEnv)[nG]
            if(isPermuted > 0) 
              ## obtain the vector of already permuted values and compute the p-value
              return((sum(get(".PERMSUM.MAT",.GlobalEnv)[isPermuted, ] >= sObserved) + 1) / (N + 1))
            
            ## at this point we don't have permuations for the current group size
            numScore <- numAllMembers(object)  ##  length(scoreVec)
            scoreVec <- allScore(object, FALSE)

            ##cat("\rComputing", N, "permutations for group size:", nG, "...\n")
            ##flush.console()
            
            if(nG > numScore / 2) { 
              ## we simply compute the sum statistic
              permSums <- sapply(1:N, function(x) sum(sample(scoreVec, nG)))
            }
            else { ## we try to do a bit of optimisation using the cumsum function
              chunkIndex <- seq.int(from = nG, to = numScore, by = nG)   
              cycles <- N %/% (length(chunkIndex) - 1) + 1
              
              permSums <-  unlist(lapply(1:cycles, function(y) {
                x <- cumsum(scoreVec[.Internal(sample(numScore, numScore, FALSE, NULL))])[chunkIndex]
                return(x[-1] - x[-length(x)])
              }), use.names = FALSE)

              length(permSums) <- N
            }
            
            return((sum(permSums >= sObserved) + 1) / (N + 1))
          })

if(!isGeneric("GOKSTiesTest"))
  setGeneric("GOKSTiesTest", function(object) standardGeneric("GOKSTiesTest"))

setMethod("GOKSTiesTest", "classicScore",
        function(object) {
            ### repurposed for KS score
            N <- numAllMembers(object)
            na <- numMembers(object)
            
            ## if the group is empty ... (should not happen, but you never know!)
            if(na == 0 || na == N)
              return(1)
            
            x.a <- rankMembers(object)
            ## x.b <- setdiff(1:N, x.a)
            
                      
            return(ks.test.2(x.a, seq_len(N)[-x.a])$ES)
            
          })

if(!isGeneric("GOKSCSWTest"))
  setGeneric("GOKSCSWTest", function(object) standardGeneric("GOKSCSWTest"))

## >> new
setMethod("GOKSCSWTest", "classicScore",
          function(object) {
            
            N <- numAllMembers(object)
            na <- numMembers(object)
            
            ## if the group is empty ... (should not happen, but you never know!)
            if(na == 0 || na == N)
              return(1)
            
            x.a <- rankMembers(object)
            ## x.b <- setdiff(1:N, x.a)
            
                      
            return(ks.test.2(x.a, seq_len(N)[-x.a])$ES)
            
          })
## >> // new

