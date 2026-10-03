# Gaussian splats and perspective taking in teacher education

Research rationale and evaluation proposal · 30 September 2026

This document explains why controllable viewpoints are worth investigating in
teacher education, and what Videographr's current experiment can and cannot
contribute. Its central proposition is that revisiting a classroom moment from
another spatial view may help teachers discuss what they noticed, what they
missed, and what remains unknowable. This is a research hypothesis, not evidence
that Gaussian splats improve teaching.

A teacher has no eyes in the back of their head and cannot attend to every group
at once. A teacher educator watching later may not have been in that classroom
at all. Recordings make parts of the event available for shared reflection;
interactive spatial representations may offer another way to examine them.
Neither recording nor reconstruction provides an all-seeing account.

## The educational problem is selective observation

Sabers, Cushing and Berliner studied teachers watching three simultaneous views
of classroom work groups. Expertise groups differed in how they perceived,
monitored and understood events. The study supports treating distributed
attention as a professional learning problem rather than assuming that more
visible material automatically produces better understanding. It did not test
Gaussian splats. [Sabers et al. 1991](https://journals.sagepub.com/doi/10.3102/00028312028001063)

There are three different kinds of absence that a teacher-education tool must
not conflate:

| Situation | What reflection can revisit | What it cannot establish |
| --- | --- | --- |
| The teacher was present but attending elsewhere | Events that the recording actually captured, with time to pause and discuss | That the teacher could or should have noticed everything simultaneously |
| The teacher educator or trainee was not in the lesson | A shared, replayable representation of the recorded situation | The complete context, relationships or experience of being there |
| The event was outside the camera or behind an obstruction | The limits of the available record and the need for another source | The missing action itself, merely by moving a virtual camera |

The educational aim is therefore not retrospective omniscience. A useful
exercise asks which information was available, which was attended to, which
interpretations are justified, and how future positioning or observation could
change that.

## Professional perspective is more than camera position

A geometric perspective is a camera's position and orientation. Professional
perspective concerns which events a teacher selects as significant and how they
interpret them. A learner's lived perspective also includes intentions,
understanding and experience. Moving a rendered camera changes the first; it
does not directly reveal the other two.

Video-club research provides a rationale for facilitated reflection. Sherin and
van Es examined two year-long clubs in which teachers discussed classroom
excerpts and reported changes in professional vision. This supports sustained,
socially scaffolded analysis of practice, not the assumption that a rendering
interface teaches noticing on its own. [Sherin and van Es 2009](https://journals.sagepub.com/doi/10.1177/0022487108328155)

For Videographr, a proposed learning mechanism is: inspect a recorded moment,
change the view, formulate a spatial question, compare with the original, then
state what evidence would be needed to answer it. The proposed activity includes
facilitation and discussion alongside navigation. A convincing picture must not replace
a reasoned explanation.

## What Gaussian splats contribute

Gaussian splatting represents a scene with many soft, overlapping primitives.
The original 3DGS method optimizes these primitives from calibrated multi-view
imagery and renders new views efficiently. This makes interactive inspection
technically attractive: a user can move through a representation instead of
selecting only among fixed pictures. The original paper establishes a rendering
method, not an educational intervention. [Kerbl et al. 2023](https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/)

The current app takes a narrower technical route. It extracts one paused video
frame, estimates relative depth locally, and displays an incomplete surface
using Gaussian primitives. Depth Anything V2 supplies a monocular depth
prediction; its base relative-depth models are distinct from separately
fine-tuned metric-depth models. The app's scale and camera assumptions are not
classroom measurements. [Yang et al. 2024](https://arxiv.org/html/2406.09414v2)

See [the implementation and setup guide](GAUSSIAN_SPLATS.md) for the exact
current controls and bounds. This experiment does not train a multi-view scene,
infer a moving person's unobserved actions, or reconstruct the room behind the
camera. It can support a discussion of spatial arrangement and missing
information, but cannot reveal a pupil who was never recorded. A surface hole
is missing evidence, not an invitation to invent it.

The alternatives differ in the information they provide:

| Representation | Available perspective change | Important limit |
| --- | --- | --- |
| Conventional video | Replay, pause and examine the recorded frame | No newly observed viewpoint |
| Captured 360 video | Look in different directions from the capture position | Looking around is not free positional movement; occlusions remain |
| Synchronized multiple cameras | Switch among actually recorded viewpoints at a shared time | Coverage and synchronization still constrain interpretation |
| Multi-view Gaussian reconstruction | Synthesize intermediate views within reconstructed coverage | Reconstruction errors and moving subjects require validation |
| Videographr's single-frame depth splats | Small virtual changes around an inferred visible surface | No extra captured evidence, calibrated geometry or unseen surfaces |

This distinction is why Gaussian splats matter as a researchable interaction
technique, not as a substitute for capture coverage. A future full multi-view
system would need a separate reconstruction, dynamic-scene validation and
privacy design; it is not an existing capability of this app.

## What adjacent teacher education research shows

Research on 360 video is relevant to controllable viewing, but is not direct
evidence for Gaussian splats.

Kosko, Ferdig and Zolfaghari reported that preservice teachers viewing 360 video
attended to more student actions than peers viewing standard video. Headset use
was also associated with different viewing patterns and more specific mathematical descriptions.
This motivates asking whether interface choices influence attention. It does
not establish transfer to inferred views, every subject area, or durable
classroom practice. [Kosko et al. 2021](https://journals.sagepub.com/doi/10.1177/0022487120939544)

Theelen and colleagues studied 141 preservice teachers in an intervention
combining 360 viewing, theory and discussion. Their pre/post results were
encouraging, but there was no control condition isolating the viewing format.
The paper explicitly leaves open whether changes transfer to actual teaching.
This is support for studying a guided learning activity, not a technology-only
effect. [Theelen et al. 2019](https://pure.tue.nl/ws/portalfiles/portal/135470196/Theelen_et_al_2019_Journal_of_Computer_Assisted_Learning.pdf)

Counterevidence is essential. Gold and Windscheid randomly assigned 59 student
teachers to conventional or 360 video. The 360 condition increased presence,
with no statistically significant difference in recognition of expert-designated
key events or teaching ratings.
Some categories favored conventional video: participants noticed more
managing-instruction events, driven by negative events. Thus, the full results
are more nuanced than a blanket claim of no noticing differences. Feeling more
present is not the same as learning more. [Gold and Windscheid 2020, sections 3.1 and 3.2 and Table 4](https://www.teachertoolkit.co.uk/wp-content/uploads/2025/02/1-s2.0-S0360131520301585-main.pdf)

This is a focused rationale, not a systematic review. The cited education
studies concern video-based learning and viewing formats; none establishes the
effectiveness of Videographr's single-frame Gaussian experiment.

## Questions worth testing

The following are proposed hypotheses, not product claims:

- Spatial orientation: limited viewpoint changes may help learners articulate
  relationships among visible desks, groups and the camera.
- Awareness of blind spots: comparison with the source may help learners say
  what cannot be known and plan where an additional observation would be useful.
- Reflective specificity: a guided perspective task may prompt more precise
  questions about a recorded event and more explicit evidence references.
- Miscalibration risk: realistic-looking synthesized views may also increase
  confidence in unsupported interpretations or distract from relevant action.
- Evidence marking: whether explicit marking of unrecorded and interpolated
  areas reduces miscalibrated confidence compared with unmarked views.

A geometric view from approximately a pupil's location must not be labeled
“what this pupil saw” or “what this pupil experienced.” In the current app even
that location is inferred and uncalibrated. Perspective taking should open a
question to discuss with participants, not assign thoughts or motives to them.

## A proposed seminar activity

Use a synthetic or appropriately authorized short recording. Explain the
difference between recorded pixels, estimated geometry and interpretation
before opening the experiment.

1. Watch the original clip and identify one moment worth discussing. Record
   an initial description without assigning motives.
2. Pause and describe which people and objects are directly visible. Name one
   area whose activity is missing or occluded; in the perspective view the hatch
   marks where no image information exists, including what the camera did not
   record.
3. Explore a small viewpoint change. Ask what changed in the representation,
   not what new event has supposedly been discovered. Use the position map to
   state how far the view is from the recorded viewpoint, and the uncertainty
   marking to see where the representation interpolates between recorded pixels.
4. Return to the original frame and replay the surrounding interval. Separate
   visible evidence, reconstruction artifacts (hatch, amber marking) and
   hypotheses.
5. Discuss an alternative teacher position, observation routine or camera
   placement that could help answer the unresolved question in a future lesson.
6. Conclude with a human-authored reflection grounded in the original recording.
   Do not export a generated view as a record of an unobserved event.

Useful prompts include: “What did I not attend to?”, “What did the camera not
record?”, “What remains uncertain after moving the view?” and “What additional
source would we need?” These prompts make the lack of eyes everywhere a topic
for professional reflection, not a personal failure to be scored.

## An evaluation that could support stronger claims

A proposed study should use staged, authorized lessons with simultaneous
events and a synchronized multi-camera reference record. The reference can
help establish what happened, while separate coding records what each study
condition actually made observable.

Randomize or counterbalance participants and matched clips across conventional
playback with pause and zoom, the same playback plus inferred splats, and a
richer captured 360 or multi-camera condition. Keep viewing time, instructions
and facilitation comparable. The first two conditions isolate the added
inferred-view interaction more closely. The richer-capture condition changes
the available evidence as well as the interface and must not be presented as
a pure renderer comparison.

Prespecify evidence-supported event descriptions, false-positive claims,
spatial reasoning, uncertainty calibration, workload and transfer to unseen
clips. Include events deliberately absent from the single-camera input:
correctly identifying “not observable” is a desirable outcome. Presence and
satisfaction are secondary outcomes, not substitutes for competence. Train
human raters, blind them to condition where feasible, report agreement and
uncertainty, and determine sample size from a declared primary outcome rather
than inventing a success threshold after collecting data.

A technical gate comes first: test view error against held-out real cameras,
moving-subject artifacts, source alignment, interaction latency and device
memory. Technical image quality alone cannot prove educational effectiveness.
Do not use results for grading teachers or judging individual pupils without
a separate, justified validation and governance process.

## Privacy and responsible use

Classroom images and reconstructed views remain potentially identifying.
Local processing reduces transfer but does not make them anonymous or create
consent. The app requires the experimental protocol and scoped authorization;
its generated scenes are temporary and excluded from study exports and human
notes. These controls do not prevent someone taking an external screenshot.

For a study, define who may view the material, the intended learning purpose,
applicable consent and review arrangements, retention, withdrawal handling and
limits on reuse before collecting it. Prefer staged or synthetic material for
development. In real classroom work, preserve the dignity of teachers and
learners: do not turn a tool for reflective uncertainty into a promise of
continuous surveillance.

## References

- Sabers, D. S., Cushing, K. S., and Berliner, D. C. (1991). Differences Among Teachers in a Task Characterized by Simultaneity, Multidimensional, and Immediacy. *American Educational Research Journal*, 28(1), 63–88. DOI: 10.3102/00028312028001063.
- Sherin, M. G., and van Es, E. A. (2009). Effects of Video Club Participation on Teachers' Professional Vision. *Journal of Teacher Education*, 60(1), 20–37. DOI: 10.1177/0022487108328155.
- Theelen, H., van den Beemt, A., and den Brok, P. (2019). Using 360-degree videos in teacher education to improve preservice teachers' professional interpersonal vision. *Journal of Computer Assisted Learning*, 35(5), 582–594. DOI: 10.1111/jcal.12361.
- Kosko, K. W., Ferdig, R. E., and Zolfaghari, M. (2021). Preservice Teachers' Professional Noticing When Viewing Standard and 360 Video. *Journal of Teacher Education*, 72(3), 284–297. DOI: 10.1177/0022487120939544.
- Gold, B., and Windscheid, J. (2020). Observing 360-degree classroom videos - Effects of video type on presence, emotions, workload, classroom observations, and ratings of teaching quality. *Computers & Education*, 156, 103960. DOI: 10.1016/j.compedu.2020.103960.
- Kerbl, B., Kopanas, G., Leimkühler, T., and Drettakis, G. (2023). 3D Gaussian Splatting for Real-Time Radiance Field Rendering. *ACM Transactions on Graphics*, 42(4), Article 139. DOI: 10.1145/3592433.
- Yang, L., Kang, B., Huang, Z., Zhao, Z., Xu, X., Feng, J., and Zhao, H. (2024). Depth Anything V2. *NeurIPS 2024*. arXiv:2406.09414.

Related repository contracts: [Scientific alpha](SCIENTIFIC_ALPHA.md),
[evaluation guide](EVALUATION.md), and [implementation guide](GAUSSIAN_SPLATS.md).
