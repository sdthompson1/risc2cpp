-- MODULE:
--   Risc2cpp.Misc
--
-- PURPOSE:
--   Miscellaneous useful routines
--
-- AUTHOR:
--   Stephen Thompson <stephen@solarflare.org.uk>
--
-- CREATED:
--   11-Feb-2011
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


module Risc2cpp.Misc
    ( toHex 
    , uniq )

where

import Data.Char
import Numeric

toHex n = "0x" ++ toHexImp 8 n

toHexImp n w = 
   let str = showIntAtBase 16 intToDigit w ""
   in take (n - length str) (repeat '0') ++ str

uniq :: Eq a => [a] -> [a]
uniq (x:y:ys) | x == y = uniq (y:ys)
uniq (x:xs) = x : uniq xs
uniq [] = []

