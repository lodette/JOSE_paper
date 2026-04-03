---
editor_options: 
  markdown: 
    wrap: 72
---

# Contributing

This project welcomes contributions and suggestions. Please submit a PR
to the `main` branch of <https://github.com/lodette/JOSE_paper> with any
updates. Make sure to update the changelog with any information about
the contribution.

## Environment Setup

### To set up an R environment for working with the LLM grader:

1.  Open the project in RStudio (or set working directory to the project
    root)

2.  Install renv if not already installed

    `install.packages("renv")`

3.  Restore all packages from the lockfile

renv::restore()

### To set up a Python environment for working with the LLM grader:

To update after adding new packages:

``` python
conda env create -f environment.yml 
conda activate jose-grader
```

To update after adding new packages:

`conda env export --from-history > environment.yml`

## Running

The Python version of the grader assumes a folder in the assignments
directory is named lab-N, containing the assignments for assignment 4,
and the program executes with the following executed in the terminal

``` python
python batch_grade.py # uses default (lab 9, or LAB_NUMBER env var if set) 
python batch_grade.py --lab-number 4 # grade lab 4 
python batch_grade.py -n 4 # short form
```

The R version of the grader similarly assumes a folder in the
assignments directory is named lab-N, containing the assignments for
assignment 4, and the program executes with the following executed in
the R Console

``` r
# Override lab number before calling main()
LAB_NUMBER <- 4
source("R/chat_grading_runner.R")
main()
```

## 
