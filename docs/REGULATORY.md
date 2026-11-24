# Intended purpose and regulatory information

Reviewed against the sources linked below on 24 November 2026.

## Scope of this release

UMMPerfusionIsiX 0.4.2 is released for software development, teaching and
exploratory perfusion-method research. The release excludes clinical
diagnosis, treatment selection, patient monitoring and report sign-off from
its intended use. Independent clinical validation is outstanding.

This repository documents no completed EU conformity assessment, CE marking
under the MDR, FDA clearance, De Novo authorization or PMA approval for this
port. Its original research papers, upstream software history, host viewer
and open-source licence do not confer such status on this release.

## European Union

MDR qualification depends on the intended purpose and the definition of a
medical device. Article 2 includes software within that definition when
intended for specified medical purposes. Intended purpose includes the
manufacturer's instructions, labelling and promotional statements.
If the software qualifies as a device, Annex VIII Rule 11 addresses software
that supplies information for diagnostic or therapeutic decisions. Such
software generally falls in Class IIa, with higher classes where the
consequences described in the rule apply. This document assigns no
definitive regulatory class to the plugin.
[Regulation (EU) 2017/745, Article 2 and Annex VIII](https://eur-lex.europa.eu/eli/reg/2017/745/oj/eng)

Qualification and classification should cover the actual proposed purpose,
software functions and their dependencies on the host viewer. MDCG 2019-11
Rev.1 provides guidance on these questions. A research label alone is
insufficient to establish the outcome of that assessment. A future medical
release would need the applicable conformity-assessment and technical
documentation processes, with evidence supporting its claimed performance.
[MDCG 2019-11 Rev.1](https://health.ec.europa.eu/system/files/2025-06/mdcg_2019_11_en.pdf)

## United States

FDA's software assessment considers intended use and functionality.
Functions intended to process or analyse medical images do not meet the
medical-image criterion for the non-device CDS exclusion in section
520(o)(1)(E) of the FD&C Act. This plugin analyses MRI data, so a proposed
medical intended use requires a device-software assessment that addresses
that functionality. The applicable classification, submission pathway or
any exemption would need to be established for the specific intended use.
[FDA Digital Health Policy Navigator, Step 6](https://www.fda.gov/medical-devices/digital-health-center-excellence/step-6-software-function-intended-provide-clinical-decision-support),
[FDA Clinical Decision Support Software guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software)

## Research and future distribution

Research involving human participants or identifiable data remains subject
to the institution's applicable ethics, privacy and research requirements.
An investigational-device study may entail additional regulatory obligations.
The repository's research scope provides no blanket authorization for a
clinical investigation or clinical deployment.

For a future medical release, the responsible organization would need to
define the purpose and users, assess the regulatory pathway, validate
clinical and technical performance, manage risks and cybersecurity, and
maintain the applicable lifecycle and post-market processes.

Public descriptions, release notes and screenshots should remain consistent
with the intended purpose documented here. Regulatory assessment of a
specific product or proposed deployment requires qualified review.
