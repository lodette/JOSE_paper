# Privacy and Ethical Considerations for AI-Assisted Assignment Grading

This document accompanies the software described in our JOSS submission and is intended to help instructors and institutions deploy this tool in compliance with applicable privacy law and ethical best practices. The legal landscape differs significantly between the United States and Canada; both are addressed below.

------------------------------------------------------------------------

## 1. The Core Privacy Issue

Student assignments are **education records** — documents directly related to an identified student and maintained by an educational institution. When an AI-assisted grading tool routes student work through a third-party large language model (LLM) API, it transmits education records to an outside party. This transmission is subject to privacy regulation regardless of whether the content is read by a human on the vendor's side.

Instructors and institutions bear the compliance obligation. This tool is designed to support responsible deployment, but it cannot enforce compliance on its own. The guidance below explains what deploying instructors need to verify before using this tool with real student work.

------------------------------------------------------------------------

## 2. United States: FERPA

### What FERPA Requires

The **Family Educational Rights and Privacy Act (FERPA)** (20 U.S.C. § 1232g) is the primary federal statute governing student education records at U.S. institutions. FERPA gives students (and parents of students under 18) the right to access, review, and control the disclosure of their education records. Institutions that receive federal funding — virtually all U.S. colleges and universities — must comply.

Disclosure of education records to a third party (such as an LLM API provider) is generally prohibited without student consent, unless an exception applies. The most relevant exception for this tool is the **"school official with legitimate educational interest"** exception, which permits disclosure to a contractor acting on behalf of the institution, provided that:

1.  The contractor is performing a service the institution would otherwise undertake itself;
2.  The disclosure is governed by a formal agreement that limits the contractor's use of the data; and
3.  The contractor does not use the data for purposes beyond the specified educational function.

### What Instructors Must Do

Before routing student assignments through any LLM API, instructors should verify that:

-   **A FERPA-compliant Data Processing Agreement (DPA) exists** between the institution and the API provider. Most large universities have negotiated enterprise agreements with major AI vendors; instructors should check with their institution's legal counsel, privacy office, or IT department before assuming such an agreement is in place.
-   **The agreement prohibits the vendor from using student data to train its models.** Historically, many general-purpose API terms of service did not provide this guarantee. Current enterprise tiers from major providers (including Anthropic and OpenAI) typically offer "zero retention" and "no training use" provisions, but these must be explicitly confirmed under the applicable agreement — default consumer API terms may not apply.
-   **Data is not retained beyond the immediate grading session** unless retention is required for audit purposes (see Section 5), and any such retention is within the institution's own infrastructure.

### Student Rights Under FERPA

Students have the right to inspect their education records and to challenge inaccurate entries. If AI-generated feedback is retained and used in grading decisions, it becomes part of the education record. Institutions should ensure:

-   AI outputs used in grading are logged and accessible for review;
-   A human instructor — not the AI alone — is the final decision-maker of record (see Section 5 on human oversight); and
-   Students are informed of the use of AI-assisted grading tools, ideally through a syllabus disclosure.

------------------------------------------------------------------------

## 3. Canada: A Multi-Jurisdictional Framework

Canada does not have a single national equivalent to FERPA. Privacy obligations for educational institutions arise from a combination of federal and provincial statutes, and the applicable law depends on the province and the nature of the institution (public vs. private).

### 3.1 Federal: PIPEDA

The **Personal Information Protection and Electronic Documents Act (PIPEDA)** (S.C. 2000, c. 5) is Canada's federal private-sector privacy law. It governs how organizations collect, use, and disclose personal information in the course of commercial activity. PIPEDA is most directly relevant to edtech vendors and commercial API providers operating in Canada, rather than to publicly funded universities themselves. However, it sets baseline principles — including purpose limitation, consent, and accountability — that inform the broader framework.

Notably, PIPEDA requires that personal information be used only for the purposes for which it was collected. Routing student assignments to an AI provider for grading purposes and then having that data used to train commercial models would violate this principle.

### 3.2 Ontario: FIPPA

The **Freedom of Information and Protection of Privacy Act (FIPPA)** (R.S.O. 1990, c. F.31) applies to Ontario's publicly funded universities and colleges. FIPPA imposes strict requirements on the collection, use, and disclosure of personal information, and — critically — includes a **server location requirement**: personal information under institutional custody or control must be stored and accessed only in Canada, unless specific exceptions apply.

This has significant practical implications:

-   Instructors at Ontario institutions **cannot route student assignments through U.S.-hosted API endpoints** unless the vendor has Canadian data residency infrastructure and the applicable service agreement explicitly routes data through Canadian servers.
-   Anthropic and OpenAI both offer data residency options in their enterprise tiers, but instructors must verify this with their institution's privacy office; it is not automatic.
-   Cloud storage of grading outputs, logs, or feedback must similarly comply with the Canadian-residency requirement.

Instructors at Ontario institutions are strongly advised to consult their institution's privacy office before deploying this tool.

### 3.3 Quebec: Law 25 (Act respecting the protection of personal information in the private sector)

Quebec's **Law 25** (formerly Bill 64, amending the *Act respecting the protection of personal information in the private sector*, R.S.Q. c. P-39.1) is the most comprehensive privacy legislation in Canada, closely aligned with the European GDPR. It applies to enterprises operating in Quebec and has been fully in force since September 2023.

Key requirements relevant to AI-assisted grading include:

-   **Privacy Impact Assessments (PIAs):** Any project involving the collection, use, communication, or retention of personal information — including new technology deployments — requires a PIA before implementation. Institutions in Quebec should conduct a PIA before deploying this tool.
-   **Transparency and consent:** Individuals must be informed of the purposes for which their personal information is used, and automated decision-making that "produces legal or significant effects" requires disclosure and the right to request human review.
-   **Data minimization:** Only the personal information necessary for the stated purpose may be collected or transmitted.
-   **Cross-border transfers:** Transferring personal information outside Quebec requires a privacy impact assessment specific to the transfer, and requires that the receiving jurisdiction or organization offers comparable protection.

### 3.4 British Columbia: FIPPA (BC)

British Columbia's **Freedom of Information and Protection of Privacy Act** (R.S.B.C. 1996, c. 165) applies to public bodies including publicly funded post-secondary institutions. Like Ontario's FIPPA, BC's version includes a **Canadian residency requirement** for personal information: data must be stored and accessed only in Canada, with limited exceptions for storage by service providers under written contracts that prohibit disclosure to foreign entities and require Canadian storage.

Instructors at BC institutions face the same API-routing concerns as those in Ontario and should verify Canadian data residency before deployment.

### 3.5 Alberta: PIPA

Alberta's **Personal Information Protection Act (PIPA)** (S.A. 2003, c. P-6.5) applies to private-sector organizations, including private post-secondary institutions in Alberta. Public universities in Alberta are covered by the provincial *Freedom of Information and Protection of Privacy Act* (Alberta FOIP). Both require consent for collection and use of personal information, purpose limitation, and reasonable security safeguards. Alberta does not have the same explicit server-location requirement as Ontario and BC, but cross-border transfers must still be disclosed and appropriate contractual protections must be in place.

------------------------------------------------------------------------

## 4. De-identification: A Hard Problem

A natural instinct is to de-identify student assignments before sending them to an AI API — stripping names, student numbers, and other obvious identifiers. This is good practice and is recommended, but instructors should not assume it eliminates privacy risk.

Student assignments, particularly long-form written work, frequently contain **quasi-identifiers** that can re-identify individuals in context:

-   References to personal experiences, locations, or relationships;
-   Distinctive writing style or idiolect;
-   GitHub usernames or handles embedded in code submissions;
-   Course-specific contextual information that narrows the population.

True de-identification of free-text is a genuinely difficult problem, and re-identification risk — while typically low — is not zero, particularly in small or specialized courses. Minimizing the data transmitted to the API (sending only the assignment content, not course metadata, rosters, or institutional identifiers) reduces but does not eliminate this risk.

------------------------------------------------------------------------

## 5. Human Oversight and the Role of the Instructor

This tool is designed to assist instructors, not to replace them. AI-generated feedback and scores should be treated as a first-pass signal that informs — but does not determine — final grades. There are several reasons this distinction matters:

**Legal:** Under FERPA and analogous Canadian statutes, grading decisions are education records for which the institution, not a commercial vendor, is responsible. Fully automated grading with no instructor review creates ambiguity about who bears accountability for those records.

**Ethical:** Students have a reasonable expectation that their academic performance will be evaluated by a qualified human who can exercise judgment, take context into account, and be held accountable. AI grading tools can reflect and amplify biases present in their training data (see Section 6); human review provides a check on these effects.

**Practical:** Instructors who review AI feedback — particularly for borderline cases — are better positioned to identify systematic errors, provide meaningful individualized feedback, and respond to student challenges.

We recommend that instructors:

-   Treat AI-generated scores as advisory rather than final;
-   Review all assignments where the AI score diverges significantly from the expected distribution;
-   Retain a log of AI outputs alongside final instructor-assigned grades for the duration required by institutional records retention policies;
-   Ensure that any student challenge to a grade is evaluated by a human, with access to the AI's output and the basis on which it was generated.

------------------------------------------------------------------------

## 6. Algorithmic Bias and Fairness

LLMs used as graders may reflect biases in their training data related to writing style, dialect, linguistic background, and cultural reference. There is documented evidence that models trained predominantly on standard academic English may systematically score writing in African American Vernacular English (AAVE), English as a second language (ESL), or other non-dominant registers differently from functionally equivalent writing in standard academic prose.

Instructors should:

-   Audit AI scores for systematic patterns across identifiable student subgroups (where data are available and consistent with privacy obligations);
-   Be attentive to courses with diverse linguistic populations;
-   Not use AI-generated scores as the sole basis for high-stakes grading decisions.

These concerns are not unique to AI grading tools — human graders exhibit similar biases — but the scale and opacity of automated systems can amplify their effects.

------------------------------------------------------------------------

## 7. Recommended Syllabus Disclosure

Instructors using this tool are encouraged to disclose its use in their course syllabus. Transparency is increasingly expected by students, required by some institutional policies, and in Quebec is arguably a legal obligation under Law 25. A brief disclosure might read:

> *This course uses AI-assisted tools to support assignment grading. AI-generated feedback is reviewed by the instructor and is advisory only; final grades are assigned by the instructor. Student work submitted for grading may be transmitted to a third-party AI service provider under the institution's data processing agreement. Students with questions about this practice are encouraged to contact the instructor or the institution's privacy office.*

------------------------------------------------------------------------

## 8. Summary Checklist for Deploying Instructors

| Step | Action |
|----|----|
| **Verify DPA** | Confirm a FERPA-compliant (US) or equivalent (Canada) data processing agreement exists between your institution and the API provider |
| **Confirm data residency** | For Ontario and BC institutions, verify that data is processed and stored in Canada |
| **Confirm no-training terms** | Verify that the API provider will not use student data to train or fine-tune models |
| **Minimize data transmitted** | Send only assignment content; avoid transmitting names, student IDs, or course metadata |
| **Conduct PIA (Quebec)** | Complete a Privacy Impact Assessment before deployment if at a Quebec institution |
| **Retain AI outputs** | Log AI-generated feedback alongside final grades for the required retention period |
| **Preserve human oversight** | Ensure an instructor reviews AI outputs and makes final grading decisions |
| **Disclose in syllabus** | Notify students that AI-assisted grading tools are in use |
| **Audit for bias** | Periodically review score distributions for evidence of systematic disparities |

------------------------------------------------------------------------

## 9. Disclaimer

This document is intended for informational purposes only and does not constitute legal advice. Privacy law is complex, jurisdiction-specific, and subject to change. Instructors and institutions should consult qualified legal counsel and their institutional privacy office before deploying this tool with real student data.
