<?php
$reportFile = ""; // /var/log/get_env/report.log
$errorFile  = ""; // /var/log/get_env/error.log
foreach ($_REQUEST as $var => $value) {
	$info = "$info$var=\"$value\";";
}
if ($info == "")
	exit;
if ($_REQUEST["error"] != "")
	$myFile = $errorFile;
else
	$myFile = $reportFile;
$info = "servertime=\"" . date("Y-m-d H:i:s") . "\";" . "ip=\"" . $_SERVER["REMOTE_ADDR"] . "\";" . "$info";
$fh = fopen($myFile, 'a') or die("can't open file");
fwrite($fh, "$info\n");
fclose($fh);
?>
