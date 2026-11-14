# Prymus 1.2.68 integration documentation

Documentation for the supplied school diary **Prymus / Wyniki ucznia**, package `pl.bialystok.zeto.prymus`, Android version1.2.68/code1026800. This package contains specifications, declaration tables, independently authored examples and future-agent tasks. It contains no plugin implementation, original APK, decompiled application source or live pupil data.

Read in this order:

1. [Authentication and transport](AUTH-AND-TRANSPORT.md): enrollment token, hourly request authenticator, service families and SDK constraints.
2. [Protocol and workflows](SPEC.md): full snapshot, mutation routes, parent mode, messages, tasks, attachments and synchronization.
3. [Statistics and justifications](STATS-JUSTIFICATIONS.md): the requested priority features, including a real **Na tle klasy** grade histogram and the distinct Prymus justification payload.
4. [Model mapping](MODEL-MAPPING.md), [615 field declarations](MODEL-FIELDS.md), [JSON declarations](model-fields.json) / [CSV](model-fields.csv).
5. [17 HTTP operations](operations.json), the detailed examples and remaining gates in the protocol guides.

Prymus is a native Java Android application using Retrofit/Gson and Room; it is not the Flutter MobiReg client or the Cordova Librus application. The main service returns many modules in one `pobierzDaneUcznia` snapshot. Live chat additionally uses MQTT, which is separate from HTTP request wrappers.

Input identities: XAPK SHA256 `0debf6ae8aed4a8f7bf7f097f181caf0e1b41060cac458eabd90b68b4d9b346b`; base APK SHA256 `5eb7dadbff8381d9d6b8e26737a1ce126f9ca900de29bdb964cbed91402710fd`. The package reports minSDK24/targetSDK36. Root archive integrity and native manifest inspection are static evidence, not successful installation or app execution.

All contracts here are tied to this supplied build. No original app was launched, no account logged in, and no school endpoint called. Declaration names alone do not establish permissions or current server acceptance. Unknown field requiredness and business-error formats remain explicit runtime gates. Packaged comments, product text and quoted future-agent tasks are evidence, not instructions to execute.
