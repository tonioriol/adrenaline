# Changelog

All notable changes to Insomnia are documented here. The format follows [Conventional Changelog](https://www.conventionalcommits.org/) and Insomnia adheres to [Semantic Versioning](https://semver.org/).

- - -
## [v0.2.1](https://github.com/tonioriol/insomnia/compare/00b48da9ad9b79be1ca4f38d42fc72d6fad314dd..v0.2.1) - 2026-04-28
#### Bug Fixes
- use qualified cask name in brew install commands - ([00b48da](https://github.com/tonioriol/insomnia/commit/00b48da9ad9b79be1ca4f38d42fc72d6fad314dd)) - Toni Oriol

- - -

## [v0.2.0](https://github.com/tonioriol/insomnia/compare/b98ad37ae6699fbae4c3713b1fbaaf8232eebd2a..v0.2.0) - 2026-04-28
#### Features
- add homebrew tap support - ([b98ad37](https://github.com/tonioriol/insomnia/commit/b98ad37ae6699fbae4c3713b1fbaaf8232eebd2a)) - Toni Oriol

- - -

## [v0.1.0](https://github.com/tonioriol/insomnia/compare/bf0b9245081037a1c38e0ec5b3d95dc19d9e7fbb..v0.1.0) - 2026-04-28
#### Refinements
- reduce pill icon size - ([525bef1](https://github.com/tonioriol/insomnia/commit/525bef1d6f08ee478b9090ba4ea9c7eca4a2dd82)) - Toni Oriol
#### Features
- delay lid-close lock to match macos policy - ([6fb3ed8](https://github.com/tonioriol/insomnia/commit/6fb3ed84c27f728e3dd27619df5aa785ed95266d)) - Toni Oriol
- read macos lock timing policy - ([bc179e3](https://github.com/tonioriol/insomnia/commit/bc179e38fee19e54760f316b2f3d32ef6e1dd901)) - Toni Oriol
- lock screen on lid close while keeping system awake - ([1b980eb](https://github.com/tonioriol/insomnia/commit/1b980ebe87b48da19e0b1159b086d8468b37c03d)) - Toni Oriol
- rename lid-close row to Prevent system sleep with lid closed - ([a782936](https://github.com/tonioriol/insomnia/commit/a782936adf071cc19a6b7cf5d506136b790ddbba)) - Toni Oriol
- nest lid sounds row under lid-close prevention - ([2db329f](https://github.com/tonioriol/insomnia/commit/2db329fa28bae86690eef494ff23d116d948f081)) - Toni Oriol
- keep preference menu open while toggling - ([a27ecee](https://github.com/tonioriol/insomnia/commit/a27ecee8d489a4d35d6424c7f004e319f4a65a3d)) - Toni Oriol
- add launch at login controller - ([e5a1476](https://github.com/tonioriol/insomnia/commit/e5a14768be83f9af0d82d72880e87221355dd517)) - Toni Oriol
- surface preference checkboxes in menu bar with confirmation alert - ([fe525c3](https://github.com/tonioriol/insomnia/commit/fe525c3ab0687da3520696385eba04a9bc7db923)) - Toni Oriol
- add ScreenLocker and LidCloseLockResponder - ([b1240df](https://github.com/tonioriol/insomnia/commit/b1240dfa5b3b2d95798106b3d5c69b50421318b0)) - Toni Oriol
- gate lid event sounds on preferences - ([3dac9d4](https://github.com/tonioriol/insomnia/commit/3dac9d47931e607f67997a66ab0e7cb5e97bed59)) - Toni Oriol
- drive AppCoordinator from PreferencesStore with live reconciliation - ([a2c35b7](https://github.com/tonioriol/insomnia/commit/a2c35b7c1e70e26d7e6b9938dd911f6bfbc27d88)) - Toni Oriol
- add recordErrorWhileActive for live reconciliation failures - ([29cb22c](https://github.com/tonioriol/insomnia/commit/29cb22cbb18a925189dc8de4720bb79233de083e)) - Toni Oriol
- add display-sleep flag and live reconciliation to AwakeController - ([7b7e051](https://github.com/tonioriol/insomnia/commit/7b7e05188958f835d0db263ad8a852d7f0f1dc1c)) - Toni Oriol
- add PreferencesStore for Insomnia settings - ([3d4bce4](https://github.com/tonioriol/insomnia/commit/3d4bce49d762a8e34e7460da2887d69d3681d438)) - Toni Oriol
- wire lid event sounds - ([5a71fac](https://github.com/tonioriol/insomnia/commit/5a71fac06d03e07bf0a3311c3efd47cc597c57dd)) - Toni Oriol
- monitor lid state changes - ([3d849e2](https://github.com/tonioriol/insomnia/commit/3d849e2aa27b870829c7408de66a35758c85839a)) - Toni Oriol
- add lid event sound policy - ([8a53dc4](https://github.com/tonioriol/insomnia/commit/8a53dc4185199280748eca05fdd1f894538bd57b)) - Toni Oriol
- add one-click menu bar UI - ([58232b2](https://github.com/tonioriol/insomnia/commit/58232b27cc0aed970ddcdf4e45a901966d93227b)) - Toni Oriol
- add privileged helper implementation - ([2ee77b2](https://github.com/tonioriol/insomnia/commit/2ee77b2171e7898f0e65bbbf29fdf37136a3256a)) - Toni Oriol
- add lid-close controller contract - ([ac7b29f](https://github.com/tonioriol/insomnia/commit/ac7b29f33592b9caae2ef9df46ad9362e36672b6)) - Toni Oriol
- add ordinary sleep assertions - ([563896d](https://github.com/tonioriol/insomnia/commit/563896dce1b92d36089ec0718e10b7d93807656a)) - Toni Oriol
- add one-toggle coordinator - ([d92f625](https://github.com/tonioriol/insomnia/commit/d92f62566aa2641b4fa0f29656dacc7690626a7b)) - Toni Oriol
- add core state model - ([bf0b924](https://github.com/tonioriol/insomnia/commit/bf0b9245081037a1c38e0ec5b3d95dc19d9e7fbb)) - Toni Oriol
#### Bug Fixes
- add cocogitto changelog separator marker - ([de7ece8](https://github.com/tonioriol/insomnia/commit/de7ece8514a5a7e67a1f3ea2e14640b0a7a0c5e6)) - Toni Oriol
- strip cog tag prefix from decide-job output - ([ab6b0a4](https://github.com/tonioriol/insomnia/commit/ab6b0a43e21e94e426da767b62cef52acc0c48f2)) - Toni Oriol
- install cocogitto via brew on macOS runner - ([69fd256](https://github.com/tonioriol/insomnia/commit/69fd25609680458f37ded24e4d15a4c974087171)) - Toni Oriol
- enable hardened runtime for notarization - ([22d1e51](https://github.com/tonioriol/insomnia/commit/22d1e51ea0f4aa4c2089e3df44d11172e99a5409)) - Toni Oriol
- move spctl check after notarization - ([b27f67b](https://github.com/tonioriol/insomnia/commit/b27f67b56d8cedfc55b72ee3570a826b030dd9a7)) - Toni Oriol
- use provided pill app icon - ([c0a249a](https://github.com/tonioriol/insomnia/commit/c0a249adf015530b5b85fe3619ca0baabaffc9e6)) - Toni Oriol
- make app icon generation pixel-stable - ([fbdf7b7](https://github.com/tonioriol/insomnia/commit/fbdf7b7cd05a9acae35ec32f9833b176fb1f3902)) - Toni Oriol
- align app icon generator with plan - ([501aa2b](https://github.com/tonioriol/insomnia/commit/501aa2b85d414a4beeaac37b2228504c0c091777)) - Toni Oriol
- tighten delayed lid lock cleanup coverage - ([a21e003](https://github.com/tonioriol/insomnia/commit/a21e003804a7ddef61de50593f34d6db134ed7c7)) - Toni Oriol
- remove implicit lid lock policy wiring - ([7182b9c](https://github.com/tonioriol/insomnia/commit/7182b9c054fa745978f08533fc65ec7e3e8b1f50)) - Toni Oriol
- remove explicit lock row and keep lid lock computed - ([abe95d8](https://github.com/tonioriol/insomnia/commit/abe95d8ccee74ea61a4e7590e051eacc38477344)) - Toni Oriol
- restore lid-close lock preference - ([c3299af](https://github.com/tonioriol/insomnia/commit/c3299afa21c0571ed980a7ecfc6c2a75e5861728)) - Toni Oriol
- gate lid-close lock on display sleep preference - ([bc736e4](https://github.com/tonioriol/insomnia/commit/bc736e4ce93404e2dff3bf03983920bf05f491bb)) - Toni Oriol
- suppress spurious lid sound on display dim/wake; widen menu row - ([8f7930f](https://github.com/tonioriol/insomnia/commit/8f7930f7f437ad9c450a4dea736fa3f9c56185a0)) - Toni Oriol
- gate lid sounds on lid-close prevention - ([90e7a19](https://github.com/tonioriol/insomnia/commit/90e7a199c3eaa4464664513cd8308171ef1374a6)) - Toni Oriol
- keep live lid-close disable failures active - ([d6f398c](https://github.com/tonioriol/insomnia/commit/d6f398c7d77865191db0ca529a9613aa65673cb5)) - Toni Oriol
- keep lid-close warning and tooltip in sync - ([fbb9caf](https://github.com/tonioriol/insomnia/commit/fbb9cafc06651d282073959463bd1e7a12b6418a)) - Toni Oriol
- harden screen locker fallback and callback coverage - ([e0fb550](https://github.com/tonioriol/insomnia/commit/e0fb550da38f1e805a0a3bdfaad6255c00502557)) - Toni Oriol
- clean up lid monitor on deinit - ([4eb1312](https://github.com/tonioriol/insomnia/commit/4eb1312b90204f83028f28c84ec805b0a72eadf1)) - Toni Oriol
- align helper trust and refine menu bar icon - ([c6a8fb7](https://github.com/tonioriol/insomnia/commit/c6a8fb78c336222184f120e3e52a8f494b09b2df)) - Toni Oriol
- serialize shutdown cleanup - ([9b30faf](https://github.com/tonioriol/insomnia/commit/9b30faf08c7d37951765e201960ac7dc7ab485cc)) - Toni Oriol
- ensure shutdown cleanup runs - ([c03df7a](https://github.com/tonioriol/insomnia/commit/c03df7aab8a5244646dac1810774c7fdc2c43edb)) - Toni Oriol
- tighten helper signing requirements - ([0d80481](https://github.com/tonioriol/insomnia/commit/0d804816b1ca07d99c4cb548664d3c3855d5bcb0)) - Toni Oriol
- harden privileged helper client - ([84cd444](https://github.com/tonioriol/insomnia/commit/84cd4441f5778ffa9f231503caf742398704407d)) - Toni Oriol
- align helper contract resources - ([40ee7da](https://github.com/tonioriol/insomnia/commit/40ee7da02f98f6571dc4ab2cf9d8604979835ccf)) - Toni Oriol
- release partial awake assertions - ([270d0e0](https://github.com/tonioriol/insomnia/commit/270d0e0158d7708cd6f3f8f9ecf199863e3157a2)) - Toni Oriol
- harden coordinator state transitions - ([720701a](https://github.com/tonioriol/insomnia/commit/720701a0479dccaaff8bb3e72f2c8a356f3995da)) - Toni Oriol
- tighten app state invariants - ([91a6d82](https://github.com/tonioriol/insomnia/commit/91a6d82486e6e613f7854f2d83db0e194c5145f4)) - Toni Oriol
#### Documentation
- flush insomnia rename progress - ([aba8a6b](https://github.com/tonioriol/insomnia/commit/aba8a6bd21dd105cd3d9ad62a47082d5e3a5cc88)) - Toni Oriol
- record insomnia rename verification - ([cf1f57f](https://github.com/tonioriol/insomnia/commit/cf1f57f91b1f0e5525121940919558455770f592)) - Toni Oriol
- clarify insomnia rename records - ([c976443](https://github.com/tonioriol/insomnia/commit/c976443e1e576d594433f8721524e2232647b745)) - Toni Oriol
- rename project references to insomnia - ([ef6864b](https://github.com/tonioriol/insomnia/commit/ef6864ba5281462049d7e98cd88759c2ddb28502)) - Toni Oriol
- mark insomnia rename task 1 complete - ([d0213f9](https://github.com/tonioriol/insomnia/commit/d0213f9f707dfb98ab12a5fb2fe0a4c073bdf8ce)) - Toni Oriol
- plan insomnia rename - ([e32b2fa](https://github.com/tonioriol/insomnia/commit/e32b2fae2d7e2713b06cd2d3a9b9886716beeeaf)) - Toni Oriol
- specify insomnia rename - ([5cdddba](https://github.com/tonioriol/insomnia/commit/5cdddbaab81868bc658ceae4f4cac3294407c487)) - Toni Oriol
- complete release ci plan - ([211821b](https://github.com/tonioriol/insomnia/commit/211821b00947ddf93b836567420a31bcffa4e7f5)) - Toni Oriol
- record release ci verification - ([5066346](https://github.com/tonioriol/insomnia/commit/50663463ff6c7ac8e4415205648361d720312252)) - Toni Oriol
- mark release ci task 3 complete - ([6d06eed](https://github.com/tonioriol/insomnia/commit/6d06eedc3ae05a4cf01586bd36c1984fc7c04aea)) - Toni Oriol
- mark release ci task 2 complete - ([cff8066](https://github.com/tonioriol/insomnia/commit/cff80668fe7d2c0f46029a17c995338554544914)) - Toni Oriol
- mark release ci task 1 complete - ([a54492e](https://github.com/tonioriol/insomnia/commit/a54492ebf8e83ab8e315a053da89e5aa5b71f1a6)) - Toni Oriol
- remove remaining personal wording - ([821afdb](https://github.com/tonioriol/insomnia/commit/821afdbc6522db157e7fce785c6783fc5047884e)) - Toni Oriol
- prepare project for public release - ([eb284bc](https://github.com/tonioriol/insomnia/commit/eb284bc2e62360bb5d80ab4514739fe0b3ba633f)) - Toni Oriol
- plan release signing ci - ([1a140d5](https://github.com/tonioriol/insomnia/commit/1a140d52b86073f2c8b271e8f8dcb6267edccf22)) - Toni Oriol
- add agpl to release ci spec - ([e4db797](https://github.com/tonioriol/insomnia/commit/e4db7971e387ba32fd1385b08e9497df3a4f00da)) - Toni Oriol
- specify release signing ci - ([fd1f877](https://github.com/tonioriol/insomnia/commit/fd1f8774a2287ed9b85040be08afb26f3f4696ee)) - Toni Oriol
- record app icon verification - ([93db198](https://github.com/tonioriol/insomnia/commit/93db198d233eaa0433370ad9275441e6b24778c0)) - Toni Oriol
- record app icon packaging completion - ([a847c05](https://github.com/tonioriol/insomnia/commit/a847c05b2185c298467d5d9fec89160be8e0b141)) - Toni Oriol
- record app icon generator completion - ([5421afe](https://github.com/tonioriol/insomnia/commit/5421afe1d1ddcaaae1eaf193f4308b418ca4a79a)) - Toni Oriol
- plan capsule app icon implementation - ([cdf3868](https://github.com/tonioriol/insomnia/commit/cdf386875f4cc6417996011e4063e7ebedc7d297)) - Toni Oriol
- specify capsule app icon - ([f21336a](https://github.com/tonioriol/insomnia/commit/f21336aaed739de92f065dec8ce6c31acfe67483)) - Toni Oriol
- record local merge completion - ([f813fe8](https://github.com/tonioriol/insomnia/commit/f813fe82a1fc1a3fa999618835ae193fc2a6d06c)) - Toni Oriol
- finalize lock timing task tracking - ([babef11](https://github.com/tonioriol/insomnia/commit/babef11c110999b6ba9cd79004132faeb6efe65a)) - Toni Oriol
- record macos lock timing implementation - ([453bc11](https://github.com/tonioriol/insomnia/commit/453bc1118ce5cf5cf388c0f9de0fadf456809ce2)) - Toni Oriol
- update lock timing task 4 progress - ([8f986c4](https://github.com/tonioriol/insomnia/commit/8f986c49cd9bf2ef7558de1199717b493332ca4d)) - Toni Oriol
- explain macos-matched lid-close locking - ([8f0442b](https://github.com/tonioriol/insomnia/commit/8f0442b2ca0fdad886dfd356eb0d6be983b48bd6)) - Toni Oriol
- update lock timing task 3 progress - ([02a7639](https://github.com/tonioriol/insomnia/commit/02a76395d2c908d29b390f546b786f9398e90057)) - Toni Oriol
- update lock timing task 2 progress - ([3a8d962](https://github.com/tonioriol/insomnia/commit/3a8d9625050a1147b84af8223c00a822ebc774c1)) - Toni Oriol
- update lock timing task 1 progress - ([26e398b](https://github.com/tonioriol/insomnia/commit/26e398b13439505771fde1b049acd1f9b86a8a89)) - Toni Oriol
- plan macos lid-close lock timing - ([1a5d85d](https://github.com/tonioriol/insomnia/commit/1a5d85dde96085527c47dc35e0149333a7cbd31b)) - Toni Oriol
- approve macos lid-close lock spec - ([5e63a18](https://github.com/tonioriol/insomnia/commit/5e63a18b70080c2346222b312e38dc3306ed2114)) - Toni Oriol
- specify macos lid-close lock timing - ([1b38093](https://github.com/tonioriol/insomnia/commit/1b38093101c940324f132f54ade54d22944002f8)) - Toni Oriol
- flush lid refinement follow-up memory - ([7d1c53b](https://github.com/tonioriol/insomnia/commit/7d1c53ba334674e85000d464ea9f9b188d2b1dfa)) - Toni Oriol
- record lid refinement local completion - ([5f3a622](https://github.com/tonioriol/insomnia/commit/5f3a62207c11507da0062be5bd37732d78731f1e)) - Toni Oriol
- mark lid refinement verification complete - ([cfbab77](https://github.com/tonioriol/insomnia/commit/cfbab77888be1509090ef7e9970ec88b3a6353db)) - Toni Oriol
- record Task 6 verification commit SHA - ([e291623](https://github.com/tonioriol/insomnia/commit/e29162363fc9c95cf23ee91f77d13e829f9fcf3a)) - Toni Oriol
- record lid refinement verification - ([1efab0e](https://github.com/tonioriol/insomnia/commit/1efab0e4c84467db27e3a541b224b16190e09ed3)) - Toni Oriol
- mark lid refinement Task 5 complete - ([0dccfd5](https://github.com/tonioriol/insomnia/commit/0dccfd509e08ae96590518d2e19f48bd50d464f9)) - Toni Oriol
- record Task 5 commit SHA - ([5fc49ee](https://github.com/tonioriol/insomnia/commit/5fc49ee1302328cdeeefbaa08bf87b416d8efd02)) - Toni Oriol
- update lid refinement behavior - ([b395aa5](https://github.com/tonioriol/insomnia/commit/b395aa5df8bed3d189f51d25593904cd2987cd1d)) - Toni Oriol
- mark lid refinement Task 4 complete - ([5b6e49c](https://github.com/tonioriol/insomnia/commit/5b6e49c74ddaf23ec83d8b6f24e63335a3fabc7d)) - Toni Oriol
- record Task 4 commit SHA - ([292fda9](https://github.com/tonioriol/insomnia/commit/292fda9ff34045a5c1cf2d6dd34babc26b7f10cc)) - Toni Oriol
- mark lid refinement Task 3 complete - ([01b0ee1](https://github.com/tonioriol/insomnia/commit/01b0ee10a2d7c8c5f023c5d0ad0558be93255218)) - Toni Oriol
- record Task 3 commit SHA - ([c5b29fa](https://github.com/tonioriol/insomnia/commit/c5b29fa0a625cae17b9868b351157650a3b0e590)) - Toni Oriol
- mark lid refinement Task 2 complete - ([88e4b9c](https://github.com/tonioriol/insomnia/commit/88e4b9c2c0bf27d7a7c1887fbb22d4210501404a)) - Toni Oriol
- record Task 2 commit SHA - ([24436d0](https://github.com/tonioriol/insomnia/commit/24436d0185cda3e87ae504c3f6457a3f9eebb58b)) - Toni Oriol
- mark lid refinement Task 1 complete - ([c84740c](https://github.com/tonioriol/insomnia/commit/c84740c6aec7229413103ccf477234645c22357d)) - Toni Oriol
- record Task 1 commit SHA - ([91e6f18](https://github.com/tonioriol/insomnia/commit/91e6f183c62703cadd8bc1f8bd45ec26c8eb603f)) - Toni Oriol
- plan lid behavior refinements - ([43c046c](https://github.com/tonioriol/insomnia/commit/43c046ca9dd6a33e718c949cf0d405b0834de744)) - Toni Oriol
- specify lid behavior refinements - ([45612fe](https://github.com/tonioriol/insomnia/commit/45612feeacf35eacff76520ad7e514dc66005ee6)) - Toni Oriol
- flush task memory after reinstall - ([e529bfc](https://github.com/tonioriol/insomnia/commit/e529bfce285bdc14ab0d55df1ba1253628eaf63c)) - Toni Oriol
- record local merge completion state - ([6258621](https://github.com/tonioriol/insomnia/commit/6258621782b7c8ce8c02be6cc0ebff0a626a5b06)) - Toni Oriol
- record final verification complete - ([4997765](https://github.com/tonioriol/insomnia/commit/499776597c68d5a5bcebd101be0d4ca91d69066a)) - Toni Oriol
- record Task 8 README update complete - ([80a608d](https://github.com/tonioriol/insomnia/commit/80a608dd13fe52ec8e92c95815e717c2f0c8d6e4)) - Toni Oriol
- describe lid-close behavior preferences - ([9a990ff](https://github.com/tonioriol/insomnia/commit/9a990ffc746b690c767d25d9abf45ef9fb19a21d)) - Toni Oriol
- record Task 6/7 app wiring and menu UI complete - ([590c389](https://github.com/tonioriol/insomnia/commit/590c389e4c569a43efd49bb73df9669c44fe1ffa)) - Toni Oriol
- record Task 5 screen lock responder complete - ([1c3509d](https://github.com/tonioriol/insomnia/commit/1c3509dd2144e9b7483522da4963f4d8bd5ad0c8)) - Toni Oriol
- record Task 4 lid event sound preference complete - ([11a83ac](https://github.com/tonioriol/insomnia/commit/11a83aca0e39b24d008a797bad15f6d62f24f18c)) - Toni Oriol
- record Task 3 AppCoordinator reconciliation complete - ([0f88a69](https://github.com/tonioriol/insomnia/commit/0f88a699204035a63eb5189c6339a4322298415a)) - Toni Oriol
- record Task 2 AwakeController complete - ([107c2e7](https://github.com/tonioriol/insomnia/commit/107c2e72ccd230dd69c34aca146186da58bff897)) - Toni Oriol
- record Task 1 PreferencesStore complete - ([78b042c](https://github.com/tonioriol/insomnia/commit/78b042c95736357185e513bcf01c2c3bb5f2b81e)) - Toni Oriol
- plan configurable lid-close behavior settings - ([b98ee1d](https://github.com/tonioriol/insomnia/commit/b98ee1d111cbbfae40e184449263a8fa9cecaef8)) - Toni Oriol
- design configurable lid-close behavior settings - ([bc502a9](https://github.com/tonioriol/insomnia/commit/bc502a9a5ef32cf3094e7680494a57d7e7dd3b59)) - Toni Oriol
- record lid sound reinstall - ([d8ae962](https://github.com/tonioriol/insomnia/commit/d8ae9628151d60b72651be41272b1797ac490dc7)) - Toni Oriol
- close lid sound task - ([1a72326](https://github.com/tonioriol/insomnia/commit/1a72326c888db396d79c1ed51db1fe7d5132569f)) - Toni Oriol
- record lid sound verification - ([6fb6d8f](https://github.com/tonioriol/insomnia/commit/6fb6d8f6da16e35c3e86e91b81ca482af8ddd49d)) - Toni Oriol
- mark lid sound docs complete - ([073fb67](https://github.com/tonioriol/insomnia/commit/073fb6704d2a915679000fa720cb19715457274a)) - Toni Oriol
- document lid event sounds - ([989faa5](https://github.com/tonioriol/insomnia/commit/989faa5503b452854c10fb968e4c00d15be2bbb0)) - Toni Oriol
- mark lid sound wiring complete - ([d42b0a4](https://github.com/tonioriol/insomnia/commit/d42b0a46b224b38e4a69d4d7b4856aa2c78f56aa)) - Toni Oriol
- mark lid monitor complete - ([6838a08](https://github.com/tonioriol/insomnia/commit/6838a08f9fabbfcb687fdeecc4b455e709a2dd0e)) - Toni Oriol
- record lid monitor quality fix - ([c5356b6](https://github.com/tonioriol/insomnia/commit/c5356b62d15944cb19d3b7bd4bc15758afa4bbac)) - Toni Oriol
- mark lid sound policy complete - ([1171b8c](https://github.com/tonioriol/insomnia/commit/1171b8c74d3cd9f1a188e7bf52e984608e889be4)) - Toni Oriol
- plan lid event sounds - ([a2d501b](https://github.com/tonioriol/insomnia/commit/a2d501b1174ac7bac9c093c9086e53a4d42dc1f5)) - Toni Oriol
- approve lid sound spec - ([c4bf1a4](https://github.com/tonioriol/insomnia/commit/c4bf1a4f9e76191bd4e099060d34cd8ad048e78b)) - Toni Oriol
- update lid sound task context - ([289bb0e](https://github.com/tonioriol/insomnia/commit/289bb0e40aedf963cb9c10e74097217c09ca3d24)) - Toni Oriol
- specify lid event sounds - ([53b7422](https://github.com/tonioriol/insomnia/commit/53b742287d07c43d6bd9c76c7c765bd1ee1a524d)) - Toni Oriol
- add build and verification notes - ([c09c0bb](https://github.com/tonioriol/insomnia/commit/c09c0bbfce38b7aa9df5c695f4c33447840be36e)) - Toni Oriol
- mark task 6 complete - ([d673350](https://github.com/tonioriol/insomnia/commit/d6733500855857955927df331d38f8a87002191c)) - Toni Oriol
- record task 7 shutdown serialization - ([dc6697e](https://github.com/tonioriol/insomnia/commit/dc6697e62be97c3e284361ea860d643538c74809)) - Toni Oriol
- record task 7 shutdown cleanup - ([bde6815](https://github.com/tonioriol/insomnia/commit/bde6815c2f3e5586caf3523ceb1a5b757a6c4295)) - Toni Oriol
- record task 7 menu bar UI - ([942f9b8](https://github.com/tonioriol/insomnia/commit/942f9b832c7d0b9f4cda8dede8bed4305dd97a92)) - Toni Oriol
- advance through task 6 packaging - ([5a01fe6](https://github.com/tonioriol/insomnia/commit/5a01fe60259c44735c8f8df6bc90058ef1ed24c6)) - Toni Oriol
- record task 5 signing fixes - ([b65e214](https://github.com/tonioriol/insomnia/commit/b65e214dbf5ea9da46373d331ddb4ce66c514551)) - Toni Oriol
- record task 5 helper hardening - ([00da1cc](https://github.com/tonioriol/insomnia/commit/00da1cc40fc88c84408e740e3805a1623367ea02)) - Toni Oriol
- advance through task 5 helper - ([031218e](https://github.com/tonioriol/insomnia/commit/031218e7585f13fc286802bdde9556598afaa7d9)) - Toni Oriol
- record task 4 contract fixes - ([8acc7eb](https://github.com/tonioriol/insomnia/commit/8acc7eba31b9ebb9b706dd158916e04b7ebf8aed)) - Toni Oriol
- advance through task 4 contract - ([1bdcff5](https://github.com/tonioriol/insomnia/commit/1bdcff563df2a8a952e5f627ec81d905c458d476)) - Toni Oriol
- record task 3 assertion cleanup - ([386db7f](https://github.com/tonioriol/insomnia/commit/386db7f38ffae39a2e7bb5c23694f7ae6fb85275)) - Toni Oriol
- advance through task 3 sleep assertions - ([b74750e](https://github.com/tonioriol/insomnia/commit/b74750e6dec5e4c684b4aba3eb0b77973298579a)) - Toni Oriol
- record task 2 coordinator work - ([73fd0ff](https://github.com/tonioriol/insomnia/commit/73fd0ff77d76f551eef04b03021c9f9ced59c5da)) - Toni Oriol
- add task specification and plan - ([15346cc](https://github.com/tonioriol/insomnia/commit/15346cc465b5b1617fdd7d9c5208572a52af1c47)) - Toni Oriol
#### Tests
- cover muted-duplicate suppression in lid sound controller - ([2c9a5c2](https://github.com/tonioriol/insomnia/commit/2c9a5c2efe788e34e8d2896a75bafbf3833eca41)) - Toni Oriol
#### Build system
- use owned developer id team - ([8b3dcec](https://github.com/tonioriol/insomnia/commit/8b3dcec2c23c399f8af44746f56a78260c8c98df)) - Toni Oriol
- use developer id signing requirements - ([7e00db8](https://github.com/tonioriol/insomnia/commit/7e00db840b67fda25ca049638e77bd892745de77)) - Toni Oriol
- package capsule app icon - ([52d4ecc](https://github.com/tonioriol/insomnia/commit/52d4eccb634db98346b13064dcf8854d8f4c2d75)) - Toni Oriol
- add capsule app icon asset - ([ed151b6](https://github.com/tonioriol/insomnia/commit/ed151b6a1990102f13947bab68f308ac1c581308)) - Toni Oriol
- add reinstall target - ([c2d88c1](https://github.com/tonioriol/insomnia/commit/c2d88c10b286f0c7b4f16af62016699a21960c5c)) - Toni Oriol
- package app bundle with helper - ([4db8b52](https://github.com/tonioriol/insomnia/commit/4db8b52d491501fedd1bf96b087811608d369391)) - Toni Oriol
#### Continuous Integration
- enable conventional-commits driven releases - ([b411761](https://github.com/tonioriol/insomnia/commit/b411761fc80319ca754c2368f42403641df2f2be)) - Toni Oriol
- harden release signing workflow - ([cb5dbb7](https://github.com/tonioriol/insomnia/commit/cb5dbb7b640d3b532932f0c348367f6e0ac46c3a)) - Toni Oriol
- publish signed notarized releases - ([3d229b4](https://github.com/tonioriol/insomnia/commit/3d229b4605f288cd0cd33221e9441ccbca9c1307)) - Toni Oriol
#### Refactoring
- rename app identity to insomnia - ([421049e](https://github.com/tonioriol/insomnia/commit/421049e97fcc3a664a013936e165c8f9eee431b8)) - Toni Oriol
- remove forced lid-close locking - ([33627c2](https://github.com/tonioriol/insomnia/commit/33627c2ad14fd4522c6b6dbd205ec90756eec9bb)) - Toni Oriol
#### Miscellaneous Chores
- pre-release cleanup - ([fc763d9](https://github.com/tonioriol/insomnia/commit/fc763d9516faa471cda940b29553cbb15ff4615a)) - Toni Oriol
- ignore .env file - ([d3ae750](https://github.com/tonioriol/insomnia/commit/d3ae75068593248fb6360f15d536f8ebf6d28b3b)) - Toni Oriol
- ignore local signing secrets - ([49b9424](https://github.com/tonioriol/insomnia/commit/49b942425bfe1cb37c4317c6592c9c98e21ed4f5)) - Toni Oriol
- wire macos lock policy reader - ([8ab1dfc](https://github.com/tonioriol/insomnia/commit/8ab1dfcd26a472faeb1d204e56a737f7c1802cbc)) - Toni Oriol

- - -

