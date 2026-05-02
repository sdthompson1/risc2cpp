-- MODULE:
--   Main
--
-- PURPOSE:
--   Main Program for Risc2cpp
--
-- AUTHOR:
--   Stephen Thompson <stephen@solarflare.org.uk>
--
-- CREATED:
--   15-Oct-2010 (original version - Mips2cs)
--   12-Apr-2025 (this version - Risc2cpp)
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


module Main where

import Risc2cpp.BasicBlock
import Risc2cpp.CodeGen
import Risc2cpp.ExtractCode
import Risc2cpp.LocalVarAlloc
import Risc2cpp.RiscVToIntermed
import Risc2cpp.Simplifier

import qualified Data.ByteString as B
import Data.Char
import Data.Elf
import Data.List
import qualified Data.Map as Map
import Data.Map (Map)
import Options.Applicative
import System.FilePath (takeFileName)
import System.IO

-- Command line options
data Options = Options
  { optimizationLevel :: Int
  , inputFilename :: String
  , outputPrefix :: String
  , splitCpp :: Maybe Int
  }

optParser :: Parser Options
optParser = Options
            <$> option auto
                    ( short 'O'
                    <> help "Optimization level (0, 1 or 2)"
                    <> showDefault
                    <> value 1
                    <> metavar "opt_level" )
            <*> strArgument
                    ( metavar "INPUT"
                    <> help "Input filename (must be a 32-bit RISC-V ELF executable)" )
            <*> strArgument
                    ( metavar "OUTPUT"
                    <> help "Output prefix - output files will be named OUTPUT.hpp and OUTPUT.cpp" )
            <*> optional (option auto
                    ( long "split-cpp"
                    <> help "Split output into multiple .cpp files with N 'exec' methods per file"
                    <> metavar "N" ))

optParserInfo :: ParserInfo Options
optParserInfo = info (optParser <**> helper)
       ( fullDesc
         <> header "Convert a 32-bit RISC-V binary to C++ code" )

-- Main Function
main :: IO ()
main = do
  opts <- customExecParser (prefs showHelpOnEmpty) optParserInfo

  -- Read input file
  elfBytestring <- B.readFile (inputFilename opts)
  let elf = parseElf elfBytestring

  -- Extract code & data chunks, and potential indirect jump targets
  -- NB: indJumpTargets0 is unsorted & may contain duplicates.
  let (indJumpTargets0, codeChunks, dataChunks, programBreak) = extractCode elf

  -- Convert code chunks to Intermediate form
  let (allIndJumpTargets, intermediateCode) = riscVToIntermed indJumpTargets0 codeChunks

  -- Extract basic blocks
  let basicBlocks = findBasicBlocks allIndJumpTargets intermediateCode

  -- Run optimization passes
  let simplified = simplify (optimizationLevel opts) allIndJumpTargets basicBlocks

  -- Generate the C++ code
  let prefix = outputPrefix opts
  let baseHppFilename = takeFileName prefix ++ ".hpp"

  let withLocVars = Map.map allocLocalVars simplified
      (hppCode, cppCode) =
          codeGen baseHppFilename
                  (splitCpp opts)
                  withLocVars
                  allIndJumpTargets
                  dataChunks
                  (fromIntegral $ elfEntry elf)
                  programBreak

  -- Save the results to the output files
  writeFile (prefix ++ ".hpp") (intercalate "\n" hppCode)
  case splitCpp opts of
    Nothing -> writeFile (prefix ++ ".cpp") (intercalate "\n" (head cppCode))
    Just _ -> mapM_ (\(fileNumber, cppChunk) -> 
               writeFile (prefix ++ "-" ++ show fileNumber ++ ".cpp") (intercalate "\n" cppChunk))
               (zip [0..] cppCode)
