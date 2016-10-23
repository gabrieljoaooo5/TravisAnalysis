# TravisAnalysis

Initial Analysis of Travis Projects

TravisAnalysis is a project in Ruby that analyses some characteristics of Travis projects. For that end, it uses some external resources: 
 - Octokit, for accessing information from GitHub Projects,
 - Travis, for getting information related to projects hosted on Github,
 - GumTree, for a syntatic diff (https://github.com/GumTreeDiff/gumtree/wiki/Getting-Started), and
 - R, for statistic analysis.

# Versions
<table style="width:100%">
  <tr>
    <th>API</th>
    <th>Version</th> 
    <th>Available on</th>
  </tr>
  <tr>
    <td>Ruby</td>
    <td>2.1.9</td> 
    <td></td>
  </tr>
  <tr>
    <td>Octokit</td>
    <td>4.3.0</td> 
    <td>https://github.com/octokit/octokit.rb/</td>
  </tr>
  <tr>
    <td>Travis</td>
    <td>1.8.3</td> 
    <td>https://github.com/travis-ci/travis.rb/</td>
  </tr>
  <tr>
    <td>GumTree</td>
    <td>gumtree-20160921-2.1.0-SNAPSHOT.zip</td> 
    <td>https://bintray.com/jrfaller/GumTree/nightlies/99.99.99#files</td>
  </tr>
</table>

For use GumTree, we recommend to download the zip file, see the table above, unzip and inform the directory where it was saved.

# Running the Analysis

All results generated by the analysis are saved as .csv files. Additionally, a initial statistical analysis is done by a R script.

To run this project, you need to follow the instructions: 

1 - Once the project is cloned, set up your information on the file "properties". 

First, you need to inform the path of directory that contains the projets to be analysed. Following, inform your login and password from GitHub to allow the extraction of information by the library Octokit. Finally, inform the directory that GumTree project was saved.

For example:

<table style="width:100%">
  <tr>
    <th>Property</th>
    <th>Example</th> 
  </tr>
  <tr>
    <td>PathAnalysis</td> 
    <td>/home/jpds/Projects/</td>
  </tr>
  <tr>
    <td>Login</td>
    <td>jpds</td> 
  </tr>
  <tr>
    <td>Password</td>
    <td>123456</td> 
  </tr>
  <tr>
    <td>PathGumTree</td>
    <td>/home/jpds/GumTree/gumtree-20160921-2.1.0-SNAPSHOT/bin/</td> 
  </tr>
</table>

2 - Run "./MainAnalysisProjects"

3 - After the execution, a new folder, ResultsAll, containing the .csv files will be created. The output of R script will be available on the R directory.

It is important that the ruby version used locally be compatible with the versions used by the external libraries.
