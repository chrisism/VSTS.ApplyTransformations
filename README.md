# ApplyTransformations (VSTS task)
VSTS/TFS Task for applying transformations on config or xml files.


### Details
When you deploy a Web site or application, you often want some settings in the deployed application's config file to be different from the development config file. For example, you might want to disable debug options and change connection strings so that they point to different databases.
With this task you can apply these transformations on .config and .xml files.

To get most out of transformations you can combine this task with a tokenizer task. You tokenize all needed configurations in the Web.release.config file and when building the
release configuration you let this task transform the original config file. Afterwards when deploying this application through the release pipeline you
use the tokenize task to change the configuration values to the ones appropiate for environment you are deploying to.

To learn more about transformations see the MSDN website at https://msdn.microsoft.com/en-us/library/dd465326(v=vs.110).aspx.


#### Available options
* **Build configuration:** The build or transform configuration. Example: release for web.release.config.
* **File extension:** The file extension to check for transforms without the dot. Example: xml