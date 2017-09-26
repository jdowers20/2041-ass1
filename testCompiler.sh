#!/bin/sh

python $1 > pyOut

./pypl.pl $1 | perl > plOut

diff pyOut plOut
