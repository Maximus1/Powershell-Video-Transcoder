using System.Windows.Forms;

// Create a new OpenFileDialog instance
OpenFileDialog dialog = new OpenFileDialog();
dialog.InitialDirectory = "C:\\Users\\"; // Initial directory (adjust as needed)
dialog.Filter = "Folder|(*.*)|UTF-8|.*";
dialog.Title = "Select a Folder";

// Show the dialog and get the result
bool result = dialog.ShowDialog();

if (result && dialog.FileName != "")
{
    string selectedFolderPath = dialog.FileName; // Get the selected folder path
}