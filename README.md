# WAVE
 Workbench for Analysis and Visualization of EM data
 
> [!NOTE]
> WAVE requires [DavesTools](https://github.com/DrMyer/DavesTools) and [DataMan](https://github.com/DrMyer/DataMan). It *might* also require [mt tools](https://github.com/DrMyer/mt), I don't recall.

> [!TIP]
> For those who prefer to do things manually, you can find a number of codes in the scriptables & utilities sub-folders that you can extract from WAVE and use stand-alone. If you take that route, then you should also have a look in the [SIO_CSEM](https://github.com/DrMyer/SIO_CSEM) repository which has a plethora of pre-WAVE tools used for almost every SIO survey since 2009.

## Note about development decisions:

+ **TO THE SCIENTISTS, POST-DOCS, PHD STUDENTS** one supreme word of advice:
take some programming classes. Software will be your most frequently used
tool. Don't skimp on your knowledge here. You will only pick up BAD HABITS
by learning from your prof's or collaborators' crappy code. It is 100%
worth your time. Trust me on this.

- The **DATA PROCESSING ROUTINES** are kept separate from the GUI elements on
purpose so that a super-user can still bypass the GUI altogether and script
all their data processing.

- The saved cwave .mat file is a class object of type cwave(). cwave
implements backwards compatibility internally through the static method
loadobj(). Saving a class to the .mat file means that the user can just
double-click a .wave.mat file and it will open the cwave UI in MatLab.
Unfortunately, in some versions of MatLab, double-clicking will open 
TWO copies of the UI. I have no idea why.

- **To the other programmers out there** who will see this code I can only say:
I'm sorry. MOST users of this code are scientists, post-docs, and students
who have never taken a software development class in their lives. They will
most likely be diving into the code and hacking away at bits and pieces of
it on the fly to try to achieve some goal or fix some bug while they are in
the field. And while I would prefer that people NOT do this and, instead,
contact me so that I can update the code myself (seemingly insignificant
changes can have major side-effects), I know too many scientists. This isn't
going to happen. So I have tried, therefore, to steer clear of more complex
coding as much as possible. Sometimes I will take a less elegant solution
instead of an elegant-but-obfuscated solution. C'est la vie.

## BUGS and FEATURE REQUESTS
Please feel free to contact me with bugs and feature requests. As of 2023 I
am actively maintaining this code. You may obtain an updated version of the
code and contact me through the bitbucket or GitHUB site for WAVE.

## FUNDING
I thank each of the following for providing the funding that enabled the
development and GNU GPL release of this code to the EM community:

### 2005-2012
I developed many of the data processing techniques under funding provided by
the Marine EM Laboratory run by Dr Steven Constable at the Scripps
Institution of Oceanography, UCSD. The routines were rewritten from
scratch in 2023 but the shape of those routines was developed back then.

### 2023
The GUI was partly developed under funding provided by Dr Eric Attias at the
OCEEMlab at the University of Texas Institute for Geophysics, UTA. This
funding was invaluable while I set aside my normal lucrative consulting to
work on this project. It's something I've wanted to do for years and Eric's
funding made it possible.

### 2012-2023
I self-funded many of the ancillary utility routines to aid my consulting
work at BlueGreen Geophysics LLC. And after I reached the end of the
OCEEMlab funding, I funded the rest of the WAVE development myself.

