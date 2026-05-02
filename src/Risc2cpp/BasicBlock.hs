-- MODULE:
--   Risc2cpp.BasicBlock
--
-- PURPOSE:
--   Extracts basic blocks from a chunk of Intermediate code
--
-- AUTHOR:
--   Stephen Thompson <stephen@solarflare.org.uk>
--
-- CREATED:
--   6-Aug-2011
--
-- COPYRIGHT:
--   Copyright (C) Stephen Thompson, 2010 - 2011, 2025.
--
-- LICENSE:
--   SPDX-License-Identifier: BSL-1.0 OR MIT
--
--   Risc2cpp is dual-licensed under the Boost Software License 1.0 or
--   the MIT License, at your option. See LICENSE-BSL-1.0 and LICENSE-MIT
--   in the project root for the full license texts.

module Risc2cpp.BasicBlock

    ( findBasicBlocks )     -- [Addr] -> [(Addr, [Statement])] -> ([Addr], Map Addr [Statement])                           

where

import Risc2cpp.Intermediate
import Risc2cpp.Misc

import Data.List
import qualified Data.Map as Map
import Data.Map (Map)


type AddrWithStmts = (Addr, [Statement])

-- Input:
--  * all indirect jump targets
--  * intermediate code (a list of (Addr, [Statement]) pairs -- one for each machine level instruction)
-- Assumptions:
--  * input addrsWithStmts is sorted in ascending order of address
--  * indirect jump targets list is NOT necessarily sorted
-- Process:
--  * Splits the code into basic blocks at:
--     * jump, syscall or break instructions (these end a block)
--     * the input indirect jump addresses (these begin a new block)
--     * any direct jump targets found in the code (these begin a new block)
-- Output:
--  * the list of basic blocks (a map of Addr to [Statement] -- one entry for each basic block.)
-- Note:
--  Output basic blocks will satisfy the following condition:
--   * Final statement is a Jump, IndirectJump, Syscall or Break
--   * The other statements are all StoreReg or StoreMem.

findBasicBlocks :: [Addr] -> [AddrWithStmts] -> Map Addr [Statement]
findBasicBlocks indirectJumpTargets addrsWithStmts =
    let allStmts = concat (map snd addrsWithStmts)
        allDirectTargets = concatMap findDirectJumpTargets allStmts
        jumpAddrs = (uniq . sort) (allDirectTargets ++ indirectJumpTargets)

        splitByJumpTargets' = splitUpList jumpAddrs addrsWithStmts   :: [[AddrWithStmts]]
        splitByJumpTargets = removeHeadIfEmpty splitByJumpTargets'  -- needed in case very first addr is actually a jump target
        truncated = map truncateAfterJump splitByJumpTargets        :: [[AddrWithStmts]]
        combined = map combineInsns (filter (/=[]) truncated)       :: [AddrWithStmts]
        basicBlocks = map addJumpIfNeeded (zip combined (tail combined ++ [error "Fell through final block!"] ))

    in Map.fromList basicBlocks

findDirectJumpTargets :: Statement -> [Addr]
findDirectJumpTargets (Jump _ a1 a2) = [a1,a2]
findDirectJumpTargets (Syscall a) = [a]
findDirectJumpTargets _ = []

splitUpList :: [Addr] -> [AddrWithStmts] -> [[AddrWithStmts]]
splitUpList [] insns = [insns]
splitUpList (end:ends) insns = 
    let (thisChunk, nextChunks) = span ((<end) . fst) insns
    in (thisChunk : splitUpList ends nextChunks)

-- this removes unreachable code in between two basic blocks
truncateAfterJump :: [AddrWithStmts] -> [AddrWithStmts]
truncateAfterJump insns = 
    let (beforeJump, jumpAndLater) = break (endsWithJump . snd) insns
    in case jumpAndLater of
         (jump:later) -> (beforeJump ++ [jump])   -- Keep the jump but drop everything afterwards.
         [] -> beforeJump  -- No jump was found, so keep everything

endsWithJump :: [Statement] -> Bool
endsWithJump [] = False
endsWithJump xs = case (last xs) of
                    Jump _ _ _ -> True
                    IndirectJump _ -> True
                    Syscall _ -> True
                    Break -> True   -- a break is considered a "jump to nowhere"!
                    _ -> False

combineInsns :: [AddrWithStmts] -> AddrWithStmts
combineInsns [] = error "combineInsns: Empty block!"
combineInsns ((a,stmts):rest) = (a, stmts ++ concatMap snd rest)

addJumpIfNeeded :: (AddrWithStmts, AddrWithStmts) -> AddrWithStmts
addJumpIfNeeded (thisBlock@(thisAddr, thisStmts), nextBlock) 
    | endsWithJump thisStmts = thisBlock
    | otherwise = case nextBlock of
                    (nextAddr, _) -> (thisAddr, thisStmts ++ [Jump (LitCond True) nextAddr nextAddr])


removeHeadIfEmpty :: [[a]] -> [[a]]
removeHeadIfEmpty ([]:xs) = xs
removeHeadIfEmpty xs = xs
