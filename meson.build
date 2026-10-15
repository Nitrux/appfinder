project(
    'appfinder',
    'cpp',
    version: '1.0.0',
    meson_version: '>=1.0.0',
    default_options: ['cpp_std=c++17', 'buildtype=release'],
)

qt6 = import('qt6')
qt = dependency('qt6', version: '>=6.9', modules: ['Core', 'Gui', 'Network', 'Qml', 'Quick', 'Widgets'])
kf6_core = dependency('KF6CoreAddons', version: '>=6.13')
cpp_compiler = meson.get_compiler('cpp')
kf6_i18n = declare_dependency(
    include_directories: include_directories(get_option('prefix') / 'include' / 'KF6' / 'KI18n'),
    dependencies: [cpp_compiler.find_library('KF6I18n'), cpp_compiler.find_library('KF6I18nQml')],
)
mauikit = dependency('MauiKit4', version: '>=4.0.5')
yaml = dependency('yaml-cpp', required: true)

git_program = find_program('git', required: false)
git_branch = 'Stable'
git_commit_hash = '0.1.0'
if git_program.found()
    git_branch_result = run_command(git_program, '-C', meson.project_source_root(), 'rev-parse', '--abbrev-ref', 'HEAD', check: false)
    git_commit_result = run_command(git_program, '-C', meson.project_source_root(), 'rev-parse', '--short', 'HEAD', check: false)
    if git_branch_result.returncode() == 0 and git_branch_result.stdout().strip() != ''
        git_branch = git_branch_result.stdout().strip()
    endif
    if git_commit_result.returncode() == 0 and git_commit_result.stdout().strip() != ''
        git_commit_hash = git_commit_result.stdout().strip()
    endif
endif

cpp_args = [
    '-DAPPFINDER_DISTROBOX_HELPER_PATH="' + get_option('libexecdir') / 'appfinder-distrobox-helper' + '"',
    '-DGIT_BRANCH="' + git_branch + '"',
    '-DGIT_COMMIT_HASH="' + git_commit_hash + '"',
]
if host_machine.cpu_family() == 'x86_64'
    cpp_args += ['-march=x86-64-v3']
endif

app_sources = [
    'src/main.cpp',
    'src/models/appmodel.cpp',
    'src/controllers/apphubbackend.cpp',
    'src/controllers/userbundlestore.cpp',
]
app_moc = qt6.preprocess(
    qresources: 'src/qml.qrc',
    moc_headers: [
        'src/models/appmodel.h',
        'src/controllers/apphubbackend.h',
    ],
)

executable(
    'appfinder',
    app_sources + app_moc,
    dependencies: [qt, kf6_core, kf6_i18n, mauikit, yaml],
    cpp_args: cpp_args,
    install: true,
)

executable(
    'appfinder-distrobox-helper',
    'src/helpers/distroboxhelper.cpp',
    dependencies: [dependency('qt6', modules: ['Core'])],
    install: true,
    install_dir: get_option('libexecdir'),
)

install_data('org.nitrux.appfinder.desktop', install_dir: get_option('datadir') / 'applications')
install_data('org.nitrux.appfinder.metainfo.xml', install_dir: get_option('datadir') / 'metainfo')
policy = configure_file(
    input: 'org.nitrux.appfinder.distrobox.policy.in',
    output: 'org.nitrux.appfinder.distrobox.policy',
    configuration: {
        'APPFINDER_DISTROBOX_HELPER_PATH': get_option('prefix') / get_option('libexecdir') / 'appfinder-distrobox-helper',
    },
)
install_data(policy, install_dir: get_option('datadir') / 'polkit-1' / 'actions')
