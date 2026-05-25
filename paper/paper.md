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

# Summary

This paper presents an open-source, LLM-based system for automatically grading long-form, mixed-format student assignments. The system processes student submissions in batch, returning a numeric grade and written feedback for each question, and is implemented in both R and Python. A JSON rubric schema and companion generation script allow instructors to define structured grading criteria without modifying the underlying code. The software is suited both for self-learning and for adoption by instructors who use text-based assignments to assess coding skills and conceptual understanding, and is particularly relevant in higher education settings where class sizes and time constraints make manual grading impractical.

The materials are licensed under the GPL-3 and have been made publicly available at: <https://github.com/lodette/JOSE_paper>, <https://doi.org/10.5281/zenodo.19410580> (code), and <https://doi.org/10.5281/zenodo.20316269> (data).

# Statement of Need

The code described here was developed in response to constrained grading resources. The authors teach a course of 45–50 students with nine assignments per term, each requiring ten questions to be graded, under a union-imposed cap of three hours per assignment. Our assignments mix multi-part programming questions in R, open-ended statistics questions that require both conceptual understanding and practical application, and closed-ended and numerical questions, so manual grading does not scale to the class size given the time constraint. The grader described here is designed for instructors of similarly structured courses: medium enrollment, mixed-format assignments, limited dedicated grading support.

As enrollments in computing/data science courses grow and grading resources remain constrained [@10.1145/3636515], approaches to the assessment scaling problem have evolved from rule-based and pattern-matching systems for multiple choice and short-answer questions [@Hussein2019Automated; @Mizumoto2023Exploring; @Ramesh2021An; @Tack2025Automated] through deep-learning and automated code-evaluation systems [@Misgna2024A; @Taghipour2016A; @Uto2023Integration] to current models leveraging large language models [@Beseiso2021A; @ElMassry2025A; @Ren2025Intelligent; @Song2024Automated; @Wang2024EffectivenessOL]. The challenge is particularly acute for massive open on-line courses (MOOCs) [@on2025].

Existing automated grading systems typically require adherence to a predefined question-and-answer framework and corresponding assignment engineering [@10.1145/3636515; @Hamrick2016]. LLMs offer greater flexibility: instructors are not constrained to a fixed question format, and grading criteria can be expressed in natural language rather than code. This makes LLM-based grading a natural fit for courses with mixed assignment types.

Recent work has applied LLMs directly to grading programming assignments [@akyash2025; @qui2025; @on2025], but these systems evaluate correctness on structured tasks and do not address the mixed-format, open-ended assignments that characterize many graduate courses. Beyond this scope limitation, usable open-source implementations remain scarce — most published work stops at prompt examples or informal workflows [@jukiewicz2025; @the2025; @zhao2025] rather than delivering a complete, reusable system. We therefore developed our own [@sarim2026].

A close open-source comparator to our work is NbGrader [@Blank2019; @Hamrick2016]. Nbgrader treats grading as test execution — instructors write executable test cells in a Jupyter notebook and the system reports pass/fail, with manual review reserved for free-response prose — while our work treats grading as judgment, handing the rubric, model solution, and student submission to an LLM that returns a numeric score and written feedback for every question. The two systems aren't really competitors but complements: nbgrader is the right answer when correctness is decidable by code, and our LLM-based grader is the right answer when it isn't. This divide is not peculiar to NbGrader. A systematic review of 121 automated grading and feedback tools published between 2017 and 2021 found that 81% relied on unit testing to assess correctness, no tool addressed open-ended mixed-format assignments, and the authors explicitly identified this as a gap for future research [@10.1145/3636515].

# Story of the project

The project began as a practical response to a teaching constraint and went through several iterations. Early versions passed only the student submission and a model solution to the LLM, expecting it to infer grading criteria from the contrast. Results were inconsistent: the model would reward partially correct answers generously in one submission and penalize the same error in the next. Adding an explicit JSON rubric — specifying criteria and point values for each question — was the turning point; grades became reproducible and feedback became actionable rather than impressionistic.

A second design decision concerned the API architecture. An early implementation used the OpenAI Assistants API, which allowed assignment materials to be uploaded once and retrieved at inference time across a batch of submissions. This reduced token overhead but introduced operational complexity — assistants had to be recreated whenever rubrics or solution files changed — and is no longer supported in OpenAI's current frontier models. The current system uses the Chat Completions API directly, passing rubric, solution, and submission together in each request, which is simpler to maintain and model-agnostic. Both implementations are included, with the Assistants-based version preserved in R for reference.

The system is deployed in a graduate Data Analytics course with 50 students and nine assignments per term. Accounting for rubric preparation, batch processing, and instructor review, it has kept total grading time within the three-hour budget.

# Implementation and reuse

Assignments are written in Quarto Markdown and hosted as per-student private repositories under a shared course GitHub organization. At the assignment deadline, students commit their final submission; the instructor clones all repositories and runs the grader, which processes every submission in batch. For each question, the grader returns a numeric grade and written feedback in a single CSV file — the primary grading artifact. Before releasing grades, the instructor spot-checks a sample of submissions for errors or server-side issues.

The grader supports a varying number of questions per assignment and can evaluate programming, open-ended statistics, and closed-ended and numerical responses. OpenAI's ChatGPT is used by default; with corresponding API keys, Anthropic's Claude and Google's Gemini can be substituted. Both R and Python implementations are provided, with dependencies handled via `renv.lock` and `environment.yml` respectively. A JSON rubric schema defines grading criteria, and a helper function generates a draft rubric from a graded copy of the assignment. Full software documentation, including pipeline descriptions, unit tests, CI workflows, and contribution guidelines, is available in the repository.

The repository also contains `docs/privacy_and_ethics.md`, which discusses privacy and ethical considerations in the use of LLM graders.

# Reliability & Rubric Conformance

The instructor reviewed five submissions after each grading run, checking scores against feedback for consistency — roughly fifteen minutes per assignment.

Reliability was assessed by running both pipelines 50 times per student on lab 4 (10 students) and lab 9 (3 students). Per-question standard deviations were typically below 0.25 grade points on the 5-point scale used in Lab 9 (5% of the question maximum) and below 0.50 grade points on the 3-point scale used in Lab 4 (17% of the question maximum), with isolated cases reaching the higher end of these ranges in both labs. R and Python means differed by less than one standard deviation in every case.

Rubric conformance was assessed via LLM meta-evaluation of feedback strings. The grader reliably attributes deductions to specific criteria but under-verifies whichever sub-criterion requires independent verification — ProcessFidelity in Lab 9 and OutputAccuracy in Lab 4. Targeted interventions improved coverage but revealed that source-code-only grading cannot distinguish semantically equivalent implementations; code execution is the principled solution for pipeline assignments. Full analysis is availble in the repository at at docs/rubric_conformance.md.

# References {#references .unnumbered}
