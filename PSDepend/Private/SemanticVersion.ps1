$code = @'
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace System.Management.Automation
{
    /// <summary>
    /// An implementation of semantic versioning (https://semver.org)
    /// that can be converted to/from <see cref="System.Version"/>.
    ///
    /// When converting to <see cref="Version"/>, a PSNoteProperty is
    /// added to the instance to store the semantic version label so
    /// that it can be recovered when creating a new SemanticVersion.
    /// </summary>
    public sealed class SemanticVersion : IComparable, IComparable<SemanticVersion>, IEquatable<SemanticVersion>
    {
        private const string VersionSansRegEx = @"^(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?$";
        private const string LabelRegEx = @"^((?<preLabel>[0-9A-Za-z][0-9A-Za-z\-\.]*))?(\+(?<buildLabel>[0-9A-Za-z][0-9A-Za-z\-\.]*))?$";
        private const string LabelUnitRegEx = @"^[0-9A-Za-z][0-9A-Za-z\-\.]*$";
        private const string PreLabelPropertyName = "PSSemVerPreReleaseLabel";
        private const string BuildLabelPropertyName = "PSSemVerBuildLabel";
        private const string TypeNameForVersionWithLabel = "System.Version#IncludeLabel";

        private string versionString;

        /// <summary>
        /// Construct a SemanticVersion from a string.
        /// </summary>
        /// <param name="version">The version to parse.</param>
        /// <exception cref="FormatException"></exception>
        /// <exception cref="OverflowException"></exception>
        public SemanticVersion(string version)
        {
            var v = SemanticVersion.Parse(version);

            major = v.Major;
            minor = v.Minor;
            patch = v.Patch < 0 ? 0 : v.Patch;
            preReleaseLabel = v.PreReleaseLabel;
            buildLabel = v.BuildLabel;
        }

        /// <summary>
        /// Construct a SemanticVersion.
        /// </summary>
        /// <param name="major">The major version.</param>
        /// <param name="minor">The minor version.</param>
        /// <param name="patch">The patch version.</param>
        /// <param name="preReleaseLabel">The pre-release label for the version.</param>
        /// <param name="buildLabel">The build metadata for the version.</param>
        /// <exception cref="FormatException">
        /// If <paramref name="preReleaseLabel"/> don't match 'LabelUnitRegEx'.
        /// If <paramref name="buildLabel"/> don't match 'LabelUnitRegEx'.
        /// </exception>
        public SemanticVersion(int major, int minor, int patch, string preReleaseLabel, string buildLabel)
            : this(major, minor, patch)
        {
            if (!string.IsNullOrEmpty(preReleaseLabel))
            {
                if (!Regex.IsMatch(preReleaseLabel, LabelUnitRegEx)) throw new FormatException("preReleaseLabel");

                this.preReleaseLabel = preReleaseLabel;
            }

            if (!string.IsNullOrEmpty(buildLabel))
            {
                if (!Regex.IsMatch(buildLabel, LabelUnitRegEx)) throw new FormatException("buildLabel");

                this.buildLabel = buildLabel;
            }
        }

        /// <summary>
        /// Construct a SemanticVersion.
        /// </summary>
        /// <param name="major">The major version.</param>
        /// <param name="minor">The minor version.</param>
        /// <param name="patch">The minor version.</param>
        /// <param name="label">The label for the version.</param>
        /// <exception cref="PSArgumentException">
        /// <exception cref="FormatException">
        /// If <paramref name="label"/> don't match 'LabelRegEx'.
        /// </exception>
        public SemanticVersion(int major, int minor, int patch, string label)
            : this(major, minor, patch)
        {
            // We presume the SymVer :
            // 1) major.minor.patch-label
            // 2) 'label' starts with letter or digit.
            if (!string.IsNullOrEmpty(label))
            {
                var match = Regex.Match(label, LabelRegEx);
                if (!match.Success) throw new FormatException("label");

                preReleaseLabel = match.Groups["preLabel"].Value;
                buildLabel = match.Groups["buildLabel"].Value;
            }
        }

        /// <summary>
        /// Construct a SemanticVersion.
        /// </summary>
        /// <param name="major">The major version.</param>
        /// <param name="minor">The minor version.</param>
        /// <param name="patch">The minor version.</param>
        /// <exception cref="PSArgumentException">
        /// If <paramref name="major"/>, <paramref name="minor"/>, or <paramref name="patch"/> is less than 0.
        /// </exception>
        public SemanticVersion(int major, int minor, int patch)
        {
            if (major < 0) throw new ArgumentException("major");
            if (minor < 0) throw new ArgumentException("minor");
            if (patch < 0) throw new ArgumentException("patch");

            this.major = major;
            this.minor = minor;
            this.patch = patch;
            // We presume:
            // PreReleaseLabel = null;
            // BuildLabel = null;
        }

        /// <summary>
        /// Construct a SemanticVersion.
        /// </summary>
        /// <param name="major">The major version.</param>
        /// <param name="minor">The minor version.</param>
        /// <exception cref="PSArgumentException">
        /// If <paramref name="major"/> or <paramref name="minor"/> is less than 0.
        /// </exception>
        public SemanticVersion(int major, int minor) : this(major, minor, 0) { }

        /// <summary>
        /// Construct a SemanticVersion.
        /// </summary>
        /// <param name="major">The major version.</param>
        /// <exception cref="PSArgumentException">
        /// If <paramref name="major"/> is less than 0.
        /// </exception>
        public SemanticVersion(int major) : this(major, 0, 0) { }

        /// <summary>
        /// Construct a <see cref="SemanticVersion"/> from a <see cref="Version"/>,
        /// copying the NoteProperty storing the label if the expected property exists.
        /// </summary>
        /// <param name="version">The version.</param>
        /// <exception cref="ArgumentNullException">
        /// If <paramref name="version"/> is null.
        /// </exception>
        /// <exception cref="PSArgumentException">
        /// If <paramref name="version.Revision"/> is more than 0.
        /// </exception>
        public SemanticVersion(Version version)
        {
            if (version == null) throw new ArgumentNullException("version");
            if (version.Revision > 0) throw new ArgumentException("version");

            major = version.Major;
            minor = version.Minor;
            patch = version.Build == -1 ? 0 : version.Build;
            var psobj = new PSObject(version);
            var preLabelNote = psobj.Properties[PreLabelPropertyName];
            if (preLabelNote != null)
            {
                preReleaseLabel = preLabelNote.Value as string;
            }

            var buildLabelNote = psobj.Properties[BuildLabelPropertyName];
            if (buildLabelNote != null)
            {
                buildLabel = buildLabelNote.Value as string;
            }
        }

        /// <summary>
        /// Convert a <see cref="SemanticVersion"/> to a <see cref="Version"/>.
        /// If there is a <see cref="PreReleaseLabel"/> or/and a <see cref="BuildLabel"/>,
        /// it is added as a NoteProperty to the result so that you can round trip
        /// back to a <see cref="SemanticVersion"/> without losing the label.
        /// </summary>
        /// <param name="semver"></param>
        public static implicit operator Version(SemanticVersion semver)
        {
            PSObject psobj;

            var result = new Version(semver.Major, semver.Minor, semver.Patch);

            if (!string.IsNullOrEmpty(semver.PreReleaseLabel) || !string.IsNullOrEmpty(semver.BuildLabel))
            {
                psobj = new PSObject(result);

                if (!string.IsNullOrEmpty(semver.PreReleaseLabel))
                {
                    psobj.Properties.Add(new PSNoteProperty(PreLabelPropertyName, semver.PreReleaseLabel));
                }

                if (!string.IsNullOrEmpty(semver.BuildLabel))
                {
                    psobj.Properties.Add(new PSNoteProperty(BuildLabelPropertyName, semver.BuildLabel));
                }

                psobj.TypeNames.Insert(0, TypeNameForVersionWithLabel);
            }

            return result;
        }

        /// <summary>
        /// The major version number, never negative.
        /// </summary>
        private int major;

        public int Major
        {
            get { return major; }
        }

        /// <summary>
        /// The minor version number, never negative.
        /// </summary>
        private int minor;

        public int Minor
        {
            get { return minor; }
        }

        /// <summary>
        /// The patch version, -1 if not specified.
        /// </summary>
        private int patch;

        public int Patch
        {
            get { return patch; }
        }


        /// <summary>
        /// PreReleaseLabel position in the SymVer string 'major.minor.patch-PreReleaseLabel+BuildLabel'.
        /// </summary>
        private string preReleaseLabel;

        public string PreReleaseLabel
        {
            get { return preReleaseLabel; }
        }


        /// <summary>
        /// BuildLabel position in the SymVer string 'major.minor.patch-PreReleaseLabel+BuildLabel'.
        /// </summary>
        private string buildLabel;

        public string BuildLabel
        {
            get { return buildLabel; }
        }


        /// <summary>
        /// Parse <paramref name="version"/> and return the result if it is a valid <see cref="SemanticVersion"/>, otherwise throws an exception.
        /// </summary>
        /// <param name="version">The string to parse.</param>
        /// <returns></returns>
        /// <exception cref="PSArgumentException"></exception>
        /// <exception cref="FormatException"></exception>
        /// <exception cref="OverflowException"></exception>
        public static SemanticVersion Parse(string version)
        {
            if (version == null) throw new ArgumentNullException("version");
            if (version == string.Empty) throw new FormatException("version");

            var r = new VersionResult();
            r.Init(true);
            TryParseVersion(version, ref r);

            return r._parsedVersion;
        }

        /// <summary>
        /// Parse <paramref name="version"/> and return true if it is a valid <see cref="SemanticVersion"/>, otherwise return false.
        /// No exceptions are raised.
        /// </summary>
        /// <param name="version">The string to parse.</param>
        /// <param name="result">The return value when the string is a valid <see cref="SemanticVersion"/></param>
        public static bool TryParse(string version, out SemanticVersion result)
        {
            if (version != null)
            {
                var r = new VersionResult();
                r.Init(false);

                if (TryParseVersion(version, ref r))
                {
                    result = r._parsedVersion;
                    return true;
                }
            }

            result = null;
            return false;
        }

        private static bool TryParseVersion(string version, ref VersionResult result)
        {
            if (version.EndsWith("-") || version.EndsWith("+") || version.EndsWith("."))
            {
                result.SetFailure(ParseFailureKind.FormatException);
                return false;
            }

            string versionSansLabel = null;
            var major = 0;
            var minor = 0;
            var patch = 0;
            string preLabel = null;
            string buildLabel = null;

            // We parse the SymVer 'version' string 'major.minor.patch-PreReleaseLabel+BuildLabel'.
            var dashIndex = version.IndexOf('-');
            var plusIndex = version.IndexOf('+');

            if (dashIndex > plusIndex)
            {
                // 'PreReleaseLabel' can contains dashes.
                if (plusIndex == -1)
                {
                    // No buildLabel: buildLabel == null
                    // Format is 'major.minor.patch-PreReleaseLabel'
                    preLabel = version.Substring(dashIndex + 1);
                    versionSansLabel = version.Substring(0, dashIndex);
                }
                else
                {
                    // No PreReleaseLabel: preLabel == null
                    // Format is 'major.minor.patch+BuildLabel'
                    buildLabel = version.Substring(plusIndex + 1);
                    versionSansLabel = version.Substring(0, plusIndex);
                    dashIndex = -1;
                }
            }
            else
            {
                if (dashIndex == -1)
                {
                    // Here dashIndex == plusIndex == -1
                    // No preLabel - preLabel == null;
                    // No buildLabel - buildLabel == null;
                    // Format is 'major.minor.patch'
                    versionSansLabel = version;
                }
                else
                {
                    // Format is 'major.minor.patch-PreReleaseLabel+BuildLabel'
                    preLabel = version.Substring(dashIndex + 1, plusIndex - dashIndex - 1);
                    buildLabel = version.Substring(plusIndex + 1);
                    versionSansLabel = version.Substring(0, dashIndex);
                }
            }

            if ((dashIndex != -1 && string.IsNullOrEmpty(preLabel)) ||
                (plusIndex != -1 && string.IsNullOrEmpty(buildLabel)) ||
                string.IsNullOrEmpty(versionSansLabel))
            {
                // We have dash and no preReleaseLabel  or
                // we have plus and no buildLabel or
                // we have no main version part (versionSansLabel==null)
                result.SetFailure(ParseFailureKind.FormatException);
                return false;
            }

            var match = Regex.Match(versionSansLabel, VersionSansRegEx);
            if (!match.Success)
            {
                result.SetFailure(ParseFailureKind.FormatException);
                return false;
            }

            if (!int.TryParse(match.Groups["major"].Value, out major))
            {
                result.SetFailure(ParseFailureKind.FormatException);
                return false;
            }

            if (match.Groups["minor"].Success && !int.TryParse(match.Groups["minor"].Value, out minor))
            {
                result.SetFailure(ParseFailureKind.FormatException);
                return false;
            }

            if (match.Groups["patch"].Success && !int.TryParse(match.Groups["patch"].Value, out patch))
            {
                result.SetFailure(ParseFailureKind.FormatException);
                return false;
            }

            if (preLabel != null && !Regex.IsMatch(preLabel, LabelUnitRegEx) ||
               (buildLabel != null && !Regex.IsMatch(buildLabel, LabelUnitRegEx)))
            {
                result.SetFailure(ParseFailureKind.FormatException);
                return false;
            }

            result._parsedVersion = new SemanticVersion(major, minor, patch, preLabel, buildLabel);
            return true;
        }

        /// <summary>
        /// Implement ToString()
        /// </summary>
        public override string ToString()
        {
            if (versionString == null)
            {
                StringBuilder result = new StringBuilder();

                //result.Append(Major).Append(Utils.Separators.Dot).Append(Minor).Append(Utils.Separators.Dot).Append(Patch);
                result.Append(Major).Append('.').Append(Minor).Append('.').Append(Patch);

                if (!string.IsNullOrEmpty(PreReleaseLabel))
                {
                    result.Append("-").Append(PreReleaseLabel);
                }

                if (!string.IsNullOrEmpty(BuildLabel))
                {
                    result.Append("+").Append(BuildLabel);
                }

                versionString = result.ToString();
            }

            return versionString;
        }

        /// <summary>
        /// Implement Compare.
        /// </summary>
        public static int Compare(SemanticVersion versionA, SemanticVersion versionB)
        {
            if (versionA != null)
            {
                return versionA.CompareTo(versionB);
            }

            if (versionB != null)
            {
                return -1;
            }

            return 0;
        }

        /// <summary>
        /// Implement <see cref="IComparable.CompareTo"/>
        /// </summary>
        public int CompareTo(object version)
        {
            if (version == null)
            {
                return 1;
            }

            var v = version as SemanticVersion;
            if (v == null)
            {
                throw new ArgumentException("version");
            }

            return CompareTo(v);
        }

        /// <summary>
        /// Implement <see cref="IComparable{T}.CompareTo"/>.
        /// Meets SymVer 2.0 p.11 https://semver.org/
        /// </summary>
        public int CompareTo(SemanticVersion value)
        {
            if ((object)value == null)
                return 1;

            if (Major != value.Major)
                return Major > value.Major ? 1 : -1;

            if (Minor != value.Minor)
                return Minor > value.Minor ? 1 : -1;

            if (Patch != value.Patch)
                return Patch > value.Patch ? 1 : -1;

            // SymVer 2.0 standard requires to ignore 'BuildLabel' (Build metadata).
            return ComparePreLabel(this.PreReleaseLabel, value.PreReleaseLabel);
        }

        /// <summary>
        /// Override <see cref="object.Equals(object)"/>
        /// </summary>
        public override bool Equals(object obj)
        {
            return Equals(obj as SemanticVersion);
        }

        /// <summary>
        /// Implement <see cref="IEquatable{T}.Equals(T)"/>
        /// </summary>
        public bool Equals(SemanticVersion other)
        {
            // SymVer 2.0 standard requires to ignore 'BuildLabel' (Build metadata).
            return other != null &&
                   (Major == other.Major) && (Minor == other.Minor) && (Patch == other.Patch) &&
                   string.Equals(PreReleaseLabel, other.PreReleaseLabel, StringComparison.Ordinal);
        }

        /// <summary>
        /// Override <see cref="object.GetHashCode()"/>
        /// </summary>
        public override int GetHashCode()
        {
            return this.ToString().GetHashCode();
        }

        /// <summary>
        /// Overloaded == operator.
        /// </summary>
        public static bool operator ==(SemanticVersion v1, SemanticVersion v2)
        {
            if (object.ReferenceEquals(v1, null))
            {
                return object.ReferenceEquals(v2, null);
            }

            return v1.Equals(v2);
        }

        /// <summary>
        /// Overloaded != operator.
        /// </summary>
        public static bool operator !=(SemanticVersion v1, SemanticVersion v2)
        {
            return !(v1 == v2);
        }

        /// <summary>
        /// Overloaded &lt; operator.
        /// </summary>
        public static bool operator <(SemanticVersion v1, SemanticVersion v2)
        {
            return (Compare(v1, v2) < 0);
        }

        /// <summary>
        /// Overloaded &lt;= operator.
        /// </summary>
        public static bool operator <=(SemanticVersion v1, SemanticVersion v2)
        {
            return (Compare(v1, v2) <= 0);
        }

        /// <summary>
        /// Overloaded &gt; operator.
        /// </summary>
        public static bool operator >(SemanticVersion v1, SemanticVersion v2)
        {
            return (Compare(v1, v2) > 0);
        }

        /// <summary>
        /// Overloaded &gt;= operator.
        /// </summary>
        public static bool operator >=(SemanticVersion v1, SemanticVersion v2)
        {
            return (Compare(v1, v2) >= 0);
        }

        private static int ComparePreLabel(string preLabel1, string preLabel2)
        {
            // Symver 2.0 standard p.9
            // Pre-release versions have a lower precedence than the associated normal version.
            // Comparing each dot separated identifier from left to right
            // until a difference is found as follows:
            //     identifiers consisting of only digits are compared numerically
            //     and identifiers with letters or hyphens are compared lexically in ASCII sort order.
            // Numeric identifiers always have lower precedence than non-numeric identifiers.
            // A larger set of pre-release fields has a higher precedence than a smaller set,
            // if all of the preceding identifiers are equal.
            if (string.IsNullOrEmpty(preLabel1)) { return string.IsNullOrEmpty(preLabel2) ? 0 : 1; }

            if (string.IsNullOrEmpty(preLabel2)) { return -1; }

            var units1 = preLabel1.Split('.');
            var units2 = preLabel2.Split('.');

            var minLength = units1.Length < units2.Length ? units1.Length : units2.Length;

            for (int i = 0; i < minLength; i++)
            {
                var ac = units1[i];
                var bc = units2[i];
                int number1, number2;
                var isNumber1 = Int32.TryParse(ac, out number1);
                var isNumber2 = Int32.TryParse(bc, out number2);

                if (isNumber1 && isNumber2)
                {
                    if (number1 != number2) { return number1 < number2 ? -1 : 1; }
                }
                else
                {
                    if (isNumber1) { return -1; }

                    if (isNumber2) { return 1; }

                    int result = string.CompareOrdinal(ac, bc);
                    if (result != 0) { return result; }
                }
            }

            return units1.Length.CompareTo(units2.Length);
        }

        internal enum ParseFailureKind
        {
            ArgumentException,
            ArgumentOutOfRangeException,
            FormatException
        }

        internal struct VersionResult
        {
            internal SemanticVersion _parsedVersion;
            internal ParseFailureKind _failure;
            internal string _exceptionArgument;
            internal bool _canThrow;

            internal void Init(bool canThrow)
            {
                _canThrow = canThrow;
            }

            internal void SetFailure(ParseFailureKind failure)
            {
                SetFailure(failure, string.Empty);
            }

            internal void SetFailure(ParseFailureKind failure, string argument)
            {
                _failure = failure;
                _exceptionArgument = argument;
                if (_canThrow)
                {
                    throw GetVersionParseException();
                }
            }

            internal Exception GetVersionParseException()
            {
                switch (_failure)
                {
                    case ParseFailureKind.ArgumentException:
                        return new ArgumentException("version");
                    case ParseFailureKind.ArgumentOutOfRangeException:
                        throw new ArgumentException("ValidateRangeTooSmall", _exceptionArgument);
                    case ParseFailureKind.FormatException:
                        // Regenerate the FormatException as would be thrown by Int32.Parse()
                        try
                        {
                            Int32.Parse(_exceptionArgument, CultureInfo.InvariantCulture);
                        }
                        catch (FormatException e)
                        {
                            return e;
                        }
                        catch (OverflowException e)
                        {
                            return e;
                        }

                        break;
                }

                return new ArgumentException("version");
            }
        }
    }
}
'@

if ($PSVersionTable.PSVersion.Major -lt 6) {
  Add-Type -TypeDefinition $code
}
