-- MODULE:
--   Risc2cpp.LocalVarAlloc
--
-- PURPOSE:
--   Renames the variables in Let statements to minimize the number of
--   local variables used by a basic block. The local variables will
--   have names "z0", "z1", "z2" etc.
--
-- AUTHOR:
--   Stephen Thompson <stephen@solarflare.org.uk>
--
-- CREATED:
--   7-Aug-2011
--
-- COPYRIGHT:
--   Copyright (C) Stephen Thompson, 2011, 2025.
--
-- LICENSE:
--   SPDX-License-Identifier: BSL-1.0 OR MIT
--
--   Risc2cpp is dual-licensed under the Boost Software License 1.0 or
--   the MIT License, at your option. See LICENSE-BSL-1.0 and LICENSE-MIT
--   in the project root for the full license texts.

module Risc2cpp.LocalVarAlloc

    ( allocLocalVars )    -- [Statement] -> [Statement]

where

import Risc2cpp.Intermediate
import Risc2cpp.Misc

import Data.List
import qualified Data.Map as Map
import Data.Map (Map)
import Data.Maybe


-- Environment handling
type LocNum = Int
type Env = Map VarName LocNum

varToLocal :: Env -> VarName -> VarName
varToLocal env varName = "z" ++ show (env Map.! varName)

substLhs :: Env -> Statement -> Statement
substLhs env (Let v e) = Let (varToLocal env v) e
substLhs env s = s

substExpr :: Env -> Expr -> Expr
substExpr env e@(LitExpr _) = e
substExpr env (VarExpr v) = VarExpr (varToLocal env v)
substExpr env (UnExpr op e) = UnExpr op (substExpr env e)
substExpr env (BinExpr op e1 e2) = BinExpr op (substExpr env e1) (substExpr env e2)
substExpr env (LoadMemExpr op e) = LoadMemExpr op (substExpr env e)
substExpr env e@(LoadRegExpr _) = e

-- 'applies' an environment to a list of statements
subst :: Env -> [Statement] -> [Statement]
subst env = map (substLhs env . mapOverExprs (substExpr env))


-- assign a new local to the given variable name.
-- takes account of which vars are still being referenced.
assignLocal :: VarName -> [Expr] -> Env -> Env
assignLocal varName exprs env = 
    let locNum = pickLocNum exprs env
    in Map.insert varName locNum env

-- pick an unused local name.
-- the local must not already be in the map, UNLESS it is unreferenced in
-- any future expression, in which case it is available for reuse.
pickLocNum :: [Expr] -> Env -> LocNum
pickLocNum exprs env = 
    let referenced = catMaybes $ map (`Map.lookup` env) (concatMap findVarsInExpr exprs)
    in pickFirstNotOf referenced

-- Finds the lowest non-negative integer that is NOT in the given list.
pickFirstNotOf :: [LocNum] -> LocNum
pickFirstNotOf xs = go 0 (uniq $ sort xs)
    where go z (x:xs) | z == x = go (z+1) xs
                      | otherwise = z
          go z [] = z

-- Input = old environment and a list of statements
-- Output = new environment
assignAllLocals :: Env -> [Statement] -> Env
assignAllLocals env ((Let v rhs):rest) = 
    let newEnv = assignLocal v (concatMap findExprsInStmt rest) env
    in assignAllLocals newEnv rest
assignAllLocals env (s:ss) = assignAllLocals env ss  -- no change to environment
assignAllLocals env [] = env


-- Top level function to rename VarExprs to local variable names.
allocLocalVars :: [Statement] -> [Statement]
allocLocalVars stmts = 
    let env = assignAllLocals Map.empty stmts
    in subst env stmts

