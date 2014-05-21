# Elo-ladder [![Build Status](https://travis-ci.org/robhoes/elo-ladder.png)](https://travis-ci.org/robhoes/elo-ladder)

_An Elo-rating based ladder competition manager_

The ladder currently has support for two types of games: chess and backgammon,
each with their own rating algorithms.

The chess algorithm is as described on http://en.wikipedia.org/wiki/ELO_rating_system.

The backgammon algorithm is the Elo-Kaufman algorithm, as popularised by FIBS.
It is described at http://www.bkgm.com/faq/Ratings.html.


## Getting involved
The results of the ladder are automatically published at
http://robhoes.github.io/elo-ladder.

Here you can also find instructions on adding yourself to the ladder and
recording games that you have played.

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
           <ID>,<Full name>,<Elo-rating>,<active>

       Where ID can be any unique string, Elo-rating is the starting
       rating for the player as an integer, and active indicates
       whether the player is retired or not.

       Examples:
           magnus,Magnus Carlsen,2870,true
           X-22,Paul Magriel,1870,true


       The GAMES file should be in CSV format:

       Syntax:
           <Date>,<Player 1's ID>,<Player 2's ID>[,<LENGTH>],<RES>

       Where the date is in ISO 8601 format (yyyy-mm-dd); IDs match those
       listed in the PLAYERS file; and RES is either 1, .5 or 0 in the case of
       a win, draw or loss for Player 1 respectively. For backgammon games,
       LENGTH is the match length (winning score); it may be omitted for chess
       games.

       Examples:
           2013-11-21,magnus,anand,.5
           2013-11-21,X-22,robertie,7,1

BUGS
       Please report bugs by opening an issue on the Elo-ladder project page
       on Github:
           https://github.com/robhoes/elo-ladder

```

## Credits

The following people have contributed to elo-ladder:
* Rob Hoes
* Si Beaumont
* Stephen Turner

