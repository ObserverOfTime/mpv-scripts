utils = require 'mp.utils'

MULTIMEDIA = table.concat({
    '*.aac',
    '*.avi',
    '*.flac',
    '*.flv',
    '*.m3u',
    '*.m3u8',
    '*.m4v',
    '*.mkv',
    '*.mov',
    '*.mp3',
    '*.mp4',
    '*.mpeg',
    '*.mpg',
    '*.oga',
    '*.ogg',
    '*.ogv',
    '*.opus',
    '*.wav',
    '*.webm',
    '*.wmv',
}, ';')

SUBTITLES = table.concat({
    '*.ass',
    '*.srt',
    '*.ssa',
    '*.sub',
    '*.txt',
}, ';')

function PowerShell(opts)
    return function()
        local template = opts.template or [[& {
            Add-Type -AssemblyName System.Windows.Forms;
            [Windows.Forms.Application]::EnableVisualStyles();
            $dialog = New-Object Windows.Forms.OpenFileDialog;
            $dialog.Filter = %q;
            $dialog.Title = %q;
            $dialog.InitialDirectory = %q;
            $dialog.Multiselect = $true;
            $dialog.ShowHelp = $true;
            $dialog.ShowDialog() > $null;
            Write-Output $dialog.FileNames;
            $dialog.Dispose();
        }]]
        local path = mp.get_property('path')
        path = path == nil and '' or utils.split_path(
            utils.join_path(utils.getcwd(), path)
        )
        local ontop = mp.get_property_native('ontop')
        mp.set_property_native('ontop', false)
        local powershell = utils.subprocess {
            args = {
                'powershell', '-NoProfile', '-Command',
                template:format(opts.text, opts.title, path)
            }, cancellable = false
        }
        mp.set_property_native('ontop', ontop)
        if powershell.status ~= 0 then return end
        for file in powershell.stdout:gmatch('[^\r\n]+') do
            mp.commandv(opts.args[1], file, opts.args[2])
        end
    end
end

mp.add_key_binding('Ctrl+f', 'open-files', PowerShell {
    title = 'Select Files',
    text = 'Multimedia Files|'..MULTIMEDIA,
    args = {'loadfile', 'append-play'},
})
mp.add_key_binding('Ctrl+F', 'open-url', PowerShell {
    title = 'Open URL',
    text = 'Enter the URL to open:',
    args = {'loadfile', 'replace'},
    template = [[& {
        Add-Type -AssemblyName Microsoft.VisualBasic;
        $url = [Microsoft.VisualBasic.Interaction]::InputBox(%q, %q);
        Write-Output $url;
    }]],
})
mp.add_key_binding('Alt+f', 'open-subs', PowerShell {
    title = 'Select Subs',
    text = 'Subtitle Files|'..SUBTITLES,
    args = {'sub-add', 'select'},
})
