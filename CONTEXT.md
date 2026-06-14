# PSDepend

A PowerShell dependency handler that resolves, installs, imports, and tests dependencies declared in `.psd1` files using a pluggable set of DependencyScripts.

## Language

**Dependency**:
The unit of work — a named, versioned item to be resolved, with a DependencyType, Target, Tags, and optional Prerequisites.
_Avoid_: package, module, requirement

**DependencyFile**:
A `.psd1` file that declares one or more Dependencies. Filename is arbitrary; `requirements.psd1` is conventional, not canonical.
_Avoid_: requirements file, depend file, manifest

**DependencyType**:
The registered identifier that selects which DependencyScript handles a Dependency (e.g., `PSGalleryModule`, `Git`, `Chocolatey`).
_Avoid_: type, provider, handler type

**DependencyScript**:
A `PSDependScripts/<Type>.ps1` file that implements a DependencyType. Receives a typed Dependency object and a set of PSDependAction flags.
_Avoid_: handler, plugin, provider

**PSDependAction**:
A set of flags (`Install`, `Test`, `Import`) passed to a DependencyScript. Flags are combinable; DependencyScripts must handle each valid combination.
_Avoid_: mode, command, operation

**Target**:
A Dependency field with dual semantics: a scope keyword (`AllUsers`, `CurrentUser`) or a filesystem path. DependencyScripts branch explicitly on which it is.
_Avoid_: destination, scope, path (use Target regardless of which semantic applies)

**PSDependOptions**:
A reserved key in a DependencyFile that sets default field values applied to all Dependencies in that file.
_Avoid_: defaults, global options, file options

**Prerequisite**:
A declared ordering constraint between Dependencies. Expressed via the `DependsOn` field; resolved into topological execution order before dispatch.
_Avoid_: dependency (to avoid confusion with the Dependency concept), requirement

**Tag**:
A label on a Dependency that controls inclusion when `Invoke-PSDepend` is called with `-Tags`.
_Avoid_: filter, category, label

## Relationships

- A **DependencyFile** contains one or more **Dependencies** and at most one **PSDependOptions** block
- A **Dependency** has exactly one **DependencyType**, which selects exactly one **DependencyScript**
- A **Dependency** may declare zero or more **Prerequisites** (other Dependencies that must resolve first)
- A **Dependency** may carry zero or more **Tags**
- A **DependencyScript** receives a **Dependency** and a set of **PSDependAction** flags on each invocation
- **Target** is a field on a **Dependency** interpreted differently by each **DependencyScript**

## Example dialogue

> **Dev:** "Should I add the new module as a dependency or a requirement?"
> **Domain expert:** "It's a **Dependency** — declared in a **DependencyFile** with `DependencyType = 'PSGalleryModule'`."

> **Dev:** "Where does it get installed — do I set the path or the scope?"
> **Domain expert:** "Both are **Target**. If you want `CurrentUser`, set `Target = 'CurrentUser'`. If you want a specific folder, set `Target = 'C:\MyModules'`. The **DependencyScript** branches on which one it sees."

> **Dev:** "I need psake to install before PowerShellBuild. How do I express that?"
> **Domain expert:** "Declare a **Prerequisite** on PowerShellBuild: `DependsOn = 'psake'`. The engine resolves all **Prerequisites** into topological order before dispatching any **DependencyScript**."

**RepositoryRegistry**:
A `Repositories` hashtable nested inside `PSDependOptions` that maps repository names to their source URLs. Used by DependencyScripts to auto-register a repository when it is not already present on the machine.
_Avoid_: repository map, source list, feed declarations

## Flagged ambiguities

- "dependency" collides with **Prerequisite** in natural speech ("psake is a dependency of PowerShellBuild") — resolved: use **Prerequisite** for the ordering relationship, **Dependency** only for a declared entry in a DependencyFile.
- "handler" was used in early CLAUDE.md — resolved: canonical term is **DependencyScript**.
