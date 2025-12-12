# Identify series of screenshot

We can create new Snapshots by sharing screenshots to Summa. When the screenshots are added to Summa, some data is extracted automatically, namely the date of the screenshot and the value represented on the screenshot.

One data point that is not yet extracted is to which series the screen shot belongs.

How would a human identify to which series the screen shot belongs?:

* Take some example screen shots of every series
* Compare the newly added screen shot and try to find similarities to the screenshots of a series, like
* Color
* Fonts and font size
* If there are 2 series with very similar design (for example if a user has 2 series that represent the values of 2 bank accounts he has at the same bank), one would also use the size / magnitude of the value to assign it to either of the 2 visually similar series.

How could we implement such a functionality? What Apple Framework would we use? How would the process look like? What are the architectural options and decisions that need to be taken?