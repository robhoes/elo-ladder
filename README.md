# Elo-ladder [![Build Status](https://travis-ci.org/simonjbeaumont/ocaml-pci-db.png)](https://travis-ci.org/robhoes/elo-ladder)

_An Elo-rating based ladder competition manager_

The algorithm is as described on http://en.wikipedia.org/wiki/ELO_rating_system.

## Commandline usage

```
NAME
       ladder - An Elo ladder system

SYNOPSIS
       ladder COMMAND ...

COMMANDS
       history
           Compute and print historic ratings of players for plotting

       print
           Compute and print ELO ladder

OPTIONS
       --help[=FMT] (default=pager)
           Show this help in format FMT (pager, plain or groff).

       --version
           Show version information.

       Use `ladder COMMAND --help' for help on a specific command.
FILE-FORMATS
       The PLAYERS file should be in CSV format:

       Syntax:
           <ID>,<Full name>,<Elo-rating>

       Where ID can be any unique string and Elo-rating is the starting
       rating for the player as an integer.

       Example:
           magnus,Magnus Carlsen,2870

       
       The GAMES file should be in CSV format:

       Syntax:
           <Date>,<White's ID>,<Black's ID>,<RES>

       Where the date is in ISO 6801 format (yyyy-mm-dd); IDs match those
       listed in the PLAYERS file; and RES is either 1, .5 or 0 in the case
       of a win, draw or loss for white respectively.

       Example:
           2013-11-21,magnus,anand,.5

BUGS
       Please report bugs by opening an issue on the Elo-ladder project page
       on Github:
           https://github.com/robhoes/elo-ladder

```
