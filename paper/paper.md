---
title: "LLM-Based Automated Grading System"
tags:
  - R
  - Python
  - education
  - automated grading
  - large language models
authors:
  - name: Muhammad Sarim
    orcid: 0009-0008-8751-2514
    affiliation: 1
  - name: Louis L. Odette
    orcid: 0009-0001-8934-6061
    affiliation: 2
affiliations:
  - name: University of Windsor School of Business, Teaching Assistant
    index: 1
  - name: University of Windsor School of Business, Sessional Instructor
    index: 2
date: 23 April 2026
bibliography: paper.bib
---

```{=html}
<!--
JOSE target budget

Title and authors        not counted
Summary                  120 to 150 words
Statement of Need        180 to 250 words
Story of the project     180 to 250 words
Implementation and reuse 150 to 200 words
Validity: Performance Against Rubrics 100 to 150 words
Acknowledgements          0 to 50 words

Target total             800 to 1000 words
-->
```

# Summary

This paper presents an open-source, LLM-based system for automatically grading long-form, mixed-format student assignments. The system processes student submissions in batch, returning a numeric grade and written feedback for each question, and is implemented in both R and Python. A JSON rubric schema and companion generation script allow instructors to define structured grading criteria without modifying the underlying code. The software is suited both for self-learning and for adoption by instructors who use text-based assignments to assess coding skills and conceptual understanding, and is particularly relevant in higher education settings where class sizes and time constraints make manual grading impractical.

The materials are licensed under the GPL-3 and have been made publicly available at: <https://github.com/lodette/JOSE_paper> and [here](https://doi.org/10.5281/zenodo.19410580).

# Statement of Need

The code described here was developed in response to constrained grading resources. The authors teach a course of 45–50 students with nine assignments per term, each requiring ten questions to be graded, under a union-imposed cap of three hours per assignment. Our assignments mix multi-part programming questions in R, open-ended statistics questions that require both conceptual understanding and practical application, and closed-ended and numerical questions, so manual grading does not scale to the class size given the time constraint.

This situation is not uncommon [@akyash2025; @qui2025; @on2025], and approaches to the assessment scaling problem have evolved from rule-based and pattern-matching systems for multiple choice and short-answer questions [@Hussein2019Automated; @Mizumoto2023Exploring; @Ramesh2021An; @Tack2024Automated] through deep-learning and automated code-evaluation systems [@Misgna2024A; @Taghipour2016A; @Uto2023Integration] to current models leveraging large language models [@Beseiso2021A; @ElMassry2025A; @Ren2025Intelligent; @Song2024Automated; @Wang2024EffectivenessOL]. The challenge is particularly acute for massive open on-line courses [@on2025].

Existing automated grading systems, both commercial [@Halgamuge2017] and open source [@Hamrick2016], often require adherence to a predefined question-and-answer framework and corresponding assignment engineering. LLMs offer greater flexibility: instructors are not constrained to a fixed question format, and grading criteria can be expressed in natural language rather than code. This makes LLM-based grading a natural fit for courses with mixed assignment types.

Despite this promise, usable open-source implementations remain scarce. Most published work stops at prompt examples or informal workflows [@jukiewicz2025; @qui2025; @the2025; @zhao2025] rather than delivering a complete, reusable system. We therefore developed our own [@sarim2026].

# Story of the project

The project began as a practical response to a teaching constraint and went through several iterations. Early versions passed only the student submission and a model solution to the LLM, expecting it to infer grading criteria from the contrast. Results were inconsistent: the model would reward partially correct answers generously in one submission and penalize the same error in the next. Adding an explicit JSON rubric — specifying criteria and point values for each question — was the turning point; grades became reproducible and feedback became actionable rather than impressionistic.

A second design decision concerned the API architecture. An early implementation used the OpenAI Assistants API, which allowed assignment materials to be uploaded once and retrieved at inference time across a batch of submissions. This reduced token overhead but introduced operational complexity — assistants had to be recreated whenever rubrics or solution files changed — and is no longer supported in OpenAI's current frontier models. The current system uses the Chat Completions API directly, passing rubric, solution, and submission together in each request, which is simpler to maintain and model-agnostic. Both implementations are included, with the Assistants-based version preserved in R for reference.

The system is deployed in a graduate Data Analytics course with 50 students and nine assignments per term. Accounting for rubric preparation, batch processing, and instructor review, it has kept total grading time within the three-hour budget. No research publications have yet used or resulted from the software.

# Implementation and reuse

Assignments are written in Quarto Markdown and hosted as per-student private repositories under a shared course GitHub organization. At the assignment deadline, students commit their final submission; the instructor clones all repositories and runs the grader, which processes every submission in batch. For each question, the grader returns a numeric grade and written feedback in a single CSV file — the primary grading artifact. Before releasing grades, the instructor spot-checks a sample of submissions for errors or server-side issues.

The grader supports a varying number of questions per assignment and can evaluate programming, open-ended statistics, and closed-ended and numerical responses. OpenAI's ChatGPT is used by default; with corresponding API keys, Anthropic's Claude and Google's Gemini can be substituted. Both R and Python implementations are provided, with dependencies handled via `renv.lock` and `environment.yml` respectively. A JSON rubric schema defines grading criteria, and a helper function generates a draft rubric from a graded copy of the assignment. Full software documentation, including pipeline descriptions, unit tests, CI workflows, and contribution guidelines, is available in the repository.

# Validity: Performance Against Rubrics

After each grading run, the instructor reviewed approximately five submissions — selected to span the grade range — checking each question's numeric score against its written feedback for internal consistency. Corrections were infrequent; this review added roughly fifteen minutes per assignment and served as the primary quality gate before grades were released.

To evaluate grading consistency, we ran both pipelines on two assignments — lab 4 (10 students) and lab 9 (3 students) — repeating each run 50 times per student per pipeline. Per-question score variance was low: most questions were graded identically on every run, and in no case did the standard deviation exceed 0.25 grade points. R and Python means per question differed by less than one standard deviation in every case. Variability, where it occurred, was concentrated in questions where student responses were ambiguous, suggesting score variance reflects genuine uncertainty in the submission rather than instability in the grader.

# References {#references .unnumbered}
