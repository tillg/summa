# Analyze Screenshots

Our app allows for easy import of screenshots from eBanking apps. The newly created ValueSnaphots have no data, just the screenshot.
Now we have imported the `ImageAnalysisService` that provides functionality to easily read images and identify data in images like screenshots.

We want top leverage this functionality to read out data from screenshots. Some thoughts:

* Scanning should automatically start when a new ValueSnapshot is created with a state that indicates it only holds an image.
* We need to rework the states and state transitions a ValueSnapshot can have. We probably want to identify
  * When scanning the screenshot should start
  * When a user looked at data - data validated by humans always overrides automatically extracted data
  * We also want to diferentiate when data is based on automatic extraction and is complete / incomplete, but not yet human-reviewed
  * Data can be imcomplete: For ex. the automatic exctracrtion might have identified the value but not the date (we will implement that later) or the series to which it belongs (also later implementation).
  * When a ValueSnapshot is being auto-processed, so the UI can indicate it
  * When auto.extraction tried but failed - obviously we want to avoid a loop
  * Pls suggest states, state names and decriptions of the states as well as their transitions
* Scanning should always happen off the UI process so the UI remains responsive.
* Every change of a ValueSnapshot should of course be saved to CloudData
