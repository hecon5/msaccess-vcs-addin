Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'---------------------------------------------------------------------------------------
' Module    : clsTranslation
' Author    : Adam Waller
' Date      : 5/15/2021
' Purpose   : Used for the translation of strings to different languages, similar to
'           : the gettext toolset.
'---------------------------------------------------------------------------------------
Option Compare Database
Option Explicit

Private Const en_US As String = "en_US"

' Cache strings to dictionary objects so we don't have to do database lookups
' each time we need to return translated strings
Private dStrings As Dictionary
Private dTranslation As Dictionary
Private m_strCurrentLanguage As String


'---------------------------------------------------------------------------------------
' Procedure : T
' Author    : Adam Waller
' Date      : 5/15/2021
' Purpose   : Return the translated version of the string.
'---------------------------------------------------------------------------------------
'
Public Function T(strText As String, Optional strContext As String) As String

    Dim strNew As String
    Dim strKey As String
    
    ' Skip processing if no value is passed
    If strText = vbNullString Then Exit Function
    
    ' Make sure the language has been initialized
    CheckInit
    
    ' Check for the master string
    strKey = BuildKey(strText, strContext)
    If dStrings.Exists(strKey) Then
        If dTranslation.Exists(dStrings(strKey)) Then
            ' Use translated string
            strNew = dTranslation(dStrings(strKey))
        End If
    Else
        ' Add to master list of strings (no translation exists)
        dStrings.Add strKey, strKey
        ' Add to strings table
        SaveString strText, strContext
    End If
    
    ' Return translated string
    T = Coalesce(strNew, strText)

End Function


'---------------------------------------------------------------------------------------
' Procedure : ApplyTo
' Author    : Adam Waller
' Date      : 5/17/2021
' Purpose   : Apply language translation to a form object (From English values)
'---------------------------------------------------------------------------------------
'
Public Sub ApplyTo(frmObject As Form)
   
    Dim ctl As Control
    Dim ctl2 As Control
    Dim ctlAsc As Control
    Dim strContext As String
    Dim strName As String
    
    ' No translation needed for English
    'If m_strCurrentLanguage = en_US Then Exit Sub
    
    ' Loop through all controls
    For Each ctl In frmObject.Controls
        
        ' Only check certain types of controls
        Select Case TypeName(ctl)
            Case "Label"
            
                ' Build base context
                strContext = frmObject.Name & "." & ctl.Name
                
                ' Check for associated control
                ' (It is easier to go from the object to the label, but not
                '  all labels may have objects, so we loop through other controls
                On Error Resume Next
                For Each ctl2 In frmObject.Controls
                    strName = vbNullString
                    strName = ctl2.Controls(0).Name
                    If strName = ctl.Name Then
                        ' Found associated label
                        ' Add extended context
                        strContext = strContext & "(" & ctl2.Name & ")"
                        Exit For
                    End If
                Next ctl2
                If DebugMode(False) Then On Error GoTo 0 Else On Error Resume Next
                
                ' Translation caption
                ctl.Caption = T(ctl.Caption, strContext)
                
            Case "TextBox"
                ' Nothing to translate
                
            Case "Page"
                ' Tab control page caption
                strContext = frmObject.Name & "." & ctl.Parent.Name & "." & ctl.Name
                ctl.Caption = T(ctl.Caption, strContext)
        
        End Select
        
    Next ctl
    
    ' Other properties
    frmObject.Caption = T(frmObject.Caption, frmObject.Name & ".Caption")

End Sub


'---------------------------------------------------------------------------------------
' Procedure : ExportTranslations
' Author    : Adam Waller
' Date      : 5/19/2021
' Purpose   : Export translations to files
'---------------------------------------------------------------------------------------
'
Public Sub ExportTranslations()

    Dim dbs As Database
    Dim rst As Recordset
    Dim strLanguage As String
    Dim strFolder As String
    Dim strFile As String
    
    strFolder = TranslationsPath
    If strFolder = vbNullString Then Exit Sub
    
    Set dbs = CodeDb
    Set rst = dbs.OpenRecordset("tblLanguages", dbOpenSnapshot)
    With rst
        Do While Not .EOF
            strLanguage = Nz(!ID)
            If strLanguage <> vbNullString Then
                If strLanguage = en_US Then
                    ' Template file (master list of strings)
                    strFile = FSO.BuildPath(strFolder, GetVBProjectForCurrentDB.Name & ".pot")
                Else
                    ' Translation work file
                    strFile = FSO.BuildPath(strFolder, strLanguage & ".po")
                End If
                WriteFile BuildFileContent(strLanguage), strFile
            End If
            .MoveNext
        Loop
        .Close
    End With

End Sub


'---------------------------------------------------------------------------------------
' Procedure : LoadTranslations
' Author    : Adam Waller
' Date      : 5/19/2021
' Purpose   : Load translation data from translation files
'---------------------------------------------------------------------------------------
'
Public Sub LoadTranslations()

End Sub


'---------------------------------------------------------------------------------------
' Procedure : TranslationsPath
' Author    : Adam Waller
' Date      : 5/19/2021
' Purpose   : Translation path saved in registry
'---------------------------------------------------------------------------------------
'
Public Property Get TranslationsPath() As String
    TranslationsPath = GetSetting(GetCodeVBProject.Name, "Language", "Translation Path", vbNullString)
End Property
Public Property Let TranslationsPath(strPath As String)
    SaveSetting GetCodeVBProject.Name, "Language", "Translation Path", strPath
End Property


'---------------------------------------------------------------------------------------
' Procedure : Contribute
' Author    : Adam Waller
' Date      : 5/19/2021
' Purpose   : Whether the user desires to contribute to translations
'---------------------------------------------------------------------------------------
'
Public Property Get Contribute() As Boolean
    Contribute = GetSetting(GetCodeVBProject.Name, "Language", "Contribute To Translations", False)
End Property
Public Property Let Contribute(blnContributeToTranslations As Boolean)
    SaveSetting GetCodeVBProject.Name, "Language", "Contribute To Translations", blnContributeToTranslations
End Property


'---------------------------------------------------------------------------------------
' Procedure : Language
' Author    : Adam Waller
' Date      : 5/19/2021
' Purpose   : Selected language
'---------------------------------------------------------------------------------------
'
Public Property Get Language() As String
    Language = GetSetting(GetCodeVBProject.Name, "Language", "Language", en_US)
End Property
Public Property Let Language(strLanguage As String)
    SaveSetting GetCodeVBProject.Name, "Language", "Language", strLanguage
End Property


'---------------------------------------------------------------------------------------
' Procedure : BuildKey
' Author    : Adam Waller
' Date      : 5/15/2021
' Purpose   : Build a dictionary key from the values, joined by pipe character
'---------------------------------------------------------------------------------------
'
Private Function BuildKey(ParamArray varParts()) As String
    BuildKey = Join(varParts, "|")
End Function


'---------------------------------------------------------------------------------------
' Procedure : SaveString
' Author    : Adam Waller
' Date      : 5/15/2021
' Purpose   : Save the string to the database table
'---------------------------------------------------------------------------------------
'
Private Sub SaveString(strText As String, strContext As String, ParamArray varParams() As Variant)
    
    Dim dbs As Database
    Dim rst As Recordset
    
    Set dbs = CodeDb
    Set rst = dbs.OpenRecordset("tblStrings")
    
    With rst
        .AddNew
            !msgid = Left$(strText, 255)
            If Len(strText) > 255 Then !FullString = strText
            !Context = strContext
            '!AddDate = Now()
        .Update
        .Close
    End With
    
End Sub



Private Sub LoadStrings()
    
End Sub


'---------------------------------------------------------------------------------------
' Procedure : SetLanguage
' Author    : Adam Waller
' Date      : 5/15/2021
' Purpose   : Set the current language
'---------------------------------------------------------------------------------------
'
Public Sub SetLanguage(strLanguage As String)
    LoadLanguage strLanguage
End Sub


'---------------------------------------------------------------------------------------
' Procedure : CheckInit
' Author    : Adam Waller
' Date      : 5/15/2021
' Purpose   : Ensure that the language strings have been loaded
'---------------------------------------------------------------------------------------
'
Private Sub CheckInit()
    If m_strCurrentLanguage = vbNullString Then
        Set dStrings = New Dictionary
        Set dTranslation = New Dictionary
        LoadLanguage GetCurrentLanguage
    End If
End Sub


'---------------------------------------------------------------------------------------
' Procedure : LoadLanguage
' Author    : Adam Waller
' Date      : 5/15/2021
' Purpose   : Loads the language entries into the dictionary objects.
'---------------------------------------------------------------------------------------
'
Private Sub LoadLanguage(strLanguage As String)
    
    Dim dbs As Database
    Dim rst As Recordset
        
    m_strCurrentLanguage = strLanguage
    Set dStrings = New Dictionary
    Set dTranslation = New Dictionary
    
    ' Load strings and translations
    Set dbs = CodeDb
    Set rst = dbs.OpenRecordset("qryStrings", dbOpenDynaset)
    With rst
        Do While Not .EOF
            If Not dStrings.Exists(!Key) Then dStrings.Add !Key, !ID
            If Nz(!Translation) <> vbNullString Then dTranslation.Add !ID, !Translation
            .MoveNext
        Loop
        .Close
    End With
    
End Sub


'---------------------------------------------------------------------------------------
' Procedure : CurrentLanguage
' Author    : Adam Waller
' Date      : 5/15/2021
' Purpose   : Return the currently selected language, falling back to operating system
'           : UI language, then to US English.
'---------------------------------------------------------------------------------------
'
Public Function GetCurrentLanguage() As String
    GetCurrentLanguage = Coalesce(m_strCurrentLanguage, GetSavedLanguage, GetOsLanguage, en_US)
End Function


Private Function GetSavedLanguage() As String

End Function


Private Function GetOsLanguage() As String

End Function


'---------------------------------------------------------------------------------------
' Procedure : Export
' Author    : Adam Waller
' Date      : 5/15/2021
' Purpose   : Export current language to .po file for translation.
'---------------------------------------------------------------------------------------
'
Public Sub ExportTranslation(Optional strPath As String)

End Sub


'---------------------------------------------------------------------------------------
' Procedure : ImportTranslation
' Author    : Adam Waller
' Date      : 5/15/2021
' Purpose   : Import a translation file. (*.po)
'---------------------------------------------------------------------------------------
'
Private Sub ImportTranslation(strFile As String)

End Sub


'---------------------------------------------------------------------------------------
' Procedure : SaveTemplate
' Author    : Adam Waller
' Date      : 5/17/2021
' Purpose   : Save the translation template file (projectname.pot)
'---------------------------------------------------------------------------------------
'
Private Sub SaveTemplate()

End Sub


'---------------------------------------------------------------------------------------
' Procedure : BuildFileContent
' Author    : Adam Waller
' Date      : 5/19/2021
' Purpose   : Creates the .po/.pot file. (en_US will be treated as a template)
'---------------------------------------------------------------------------------------
'
Private Function BuildFileContent(strLanguage As String) As String

    Dim dbs As Database
    Dim rst As Recordset
    Dim strHeader As String
    
    With New clsConcat
        .AppendOnAdd = vbCrLf
    
        
        ' File header section
        If strLanguage <> en_US Then
            ' Look up saved header
            strHeader = Nz(DLookup("Header", "tblLanguages", "ID='" & strLanguage & "'"))
        End If
        
        If strLanguage = en_US Or strHeader = vbNullString Then
            ' Build default file header.
            .Add "# Version Control System (msaccess-vcs-integration)"
            .Add "# https://github.com/joyfullservice/msaccess-vcs-integration"
            .Add "# This file is distributed under the project's BSD-style license"
            .Add "#"
            .Add "msgid """""
            .Add "msgstr """""
            .Add Q("Project-Id-Version: " & AppVersion & "\n")
            .Add Q("POT-Creation-Date: " & Format(Now, "yyyy-mm-dd hh:nn") & "\n")
            .Add Q("PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n")
            .Add Q("Last-Translator: FULL NAME <EMAIL@ADDRESS>\n")
            .Add Q("Language-Team: LANGUAGE <LL@li.org>\n")
            .Add Q("MIME-Version: 1.0\n")
            .Add Q("Content-Type: text/plain; charset=UTF-8\n")
            .Add Q("Content-Transfer-Encoding: ENCODING\n")
        Else
            ' Use saved header
            .Add strHeader
        End If
        
        ' Load strings from database
        Set dbs = CodeDb
        Set rst = dbs.OpenRecordset( _
            "select * from qryStrings where language='" & strLanguage & "' or language is null", _
            dbOpenSnapshot)
    
        ' Loop through strings
        Do While Not rst.EOF
            .Add vbNullString ' (blank line)
            .Add "#: ", Nz(rst!Context)
            .Add "msgid ", Q(Nz(rst!msgid))
            .Add "msgstr ", Q(Nz(rst!Translation))
            rst.MoveNext
        Loop
        rst.Close
        
        ' Return assembled content
        BuildFileContent = .GetStr
    End With

End Function


'---------------------------------------------------------------------------------------
' Procedure : Q
' Author    : Adam Waller
' Date      : 5/19/2021
' Purpose   : Quotes the string, and escapes any embedded quotes. Also breaks long
'           : strings into multiple lines and replaces vbCrLf with \n.
'---------------------------------------------------------------------------------------
'
Private Function Q(strText As String) As String

    ' Maximum line length
    Const MAX_LEN As Integer = 70

    Dim strNew As String
    Dim intPos As Integer
    Dim intStart As Integer
    
    ' Replace newlines and quotes with placeholder
    strNew = Replace(strText, vbCrLf, "\n")
    strNew = Replace(strNew, """", "\""")
    
    ' Add line breaks for over 70 characters.
    ' (80 characters is standard for PO files)
    If Len(strNew) > 70 Then
        
        With New clsConcat
            
            ' Start with blank string
            .Add """"""
            
            ' Begin at first character
            intStart = 1
            
            ' Continue while
            Do While intStart < Len(strNew)
                intPos = MAX_LEN
                ' Walk backwards through the string, looking for spaces
                ' where we can break the line.
                For intPos = (intStart + MAX_LEN) To intStart Step -1
                    If Mid$(strNew, intPos, 1) = " " Then
                        ' Break here after space
                        intPos = intPos + 1
                        Exit For
                    End If
                Next intPos
                ' Use full max length if we don't find a space
                If intPos = intStart - 1 Then intPos = intStart + MAX_LEN
                ' Break string here, and move start
                .Add vbCrLf, """", Mid$(strNew, intStart, intPos - intStart), """"
                intStart = intPos
                ' Add final partial string
                If Len(strNew) - intStart < MAX_LEN Then
                    .Add vbCrLf, """", Mid$(strNew, intStart), """"
                    Exit Do
                End If
                
                ' for debugging
                DoEvents
            Loop
            
            ' Return multi-line result
            Q = .GetStr
        End With
    Else
        ' Return single line
        Q = """" & strNew & """"
    End If
    
End Function