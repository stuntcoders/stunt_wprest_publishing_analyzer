# WordPress Rest API Analyzer

Script depends on:
* [csvkit](https://csvkit.readthedocs.io/en/0.9.1/install.html)
* [gawk](https://www.gnu.org/software/gawk/)
* [jsonv](https://github.com/archan937/jsonv.sh)
* [gnuplot](http://www.gnuplot.info/download.html)

To run it, first install the tool:
```
wget https://raw.githubusercontent.com/stuntcoders/stunt_wprest_publishing_analyzer/master/wpanalyzer.sh
sudo chmod +x ./wpanalyzer.sh
sudo cp ./wpanalyzer.sh /usr/local/bin/wpanalyzer
```

Then run following command:
```
wpanalyzer example.com
```

Script is assuming website is running under https, so if particular website you wish to analyze does not have SSL installed, make sure to run script with following command:
```
wpanalyzer example.com http
```

Do you wish to analyze multiple sites and have all results stored in one file for better overview? You can do that like this:
```
wpanalyzer site-one.com http file
wpanalyzer site-two.com http file
...
open wpanalyzer.csv
```

Copyright [StuntCoders](https://stuntcoders.com/)
