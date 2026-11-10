var framework = System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription;
Console.WriteLine(framework);
return framework.Contains("10.", StringComparison.Ordinal) ? 0 : 1;
