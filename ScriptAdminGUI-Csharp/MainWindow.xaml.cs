using System;
using System.Collections.Generic;
using System.DirectoryServices;
using System.Net;
using System.Windows;
using System.Windows.Controls;
using System.Diagnostics;

namespace ScriptAdminCSharp
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
        }

        private void BtnSearch_Click(object sender, RoutedEventArgs e)
        {
            Log("Recherche lancée pour : " + SearchBox.Text);
            ResultsList.Items.Clear();
            try
            {
                var results = SearchComputersAD(SearchBox.Text);
                foreach (var item in results)
                {
                    ResultsList.Items.Add(item);
                }
                Log($"{results.Count} résultat(s) trouvé(s).");
            }
            catch (Exception ex)
            {
                Log("Erreur lors de la recherche AD : " + ex.Message);
            }
        }

        private List<ComputerResult> SearchComputersAD(string search)
        {
            var list = new List<ComputerResult>();
            string ldapPath = "LDAP://DC=st-paul,DC=dom";
            using (DirectoryEntry entry = new DirectoryEntry(ldapPath))
            using (DirectorySearcher searcher = new DirectorySearcher(entry))
            {
                // Recherche sur le nom OU la description (nom d'utilisateur)
                searcher.Filter = $"(&(objectCategory=computer)(|(cn=*{search}*)(description=*{search}*)))";
                searcher.PropertiesToLoad.Add("cn");
                searcher.PropertiesToLoad.Add("description");
                searcher.SizeLimit = 50;
                searcher.SearchScope = SearchScope.Subtree;

                foreach (SearchResult res in searcher.FindAll())
                {
                    string name = res.Properties["cn"].Count > 0 ? res.Properties["cn"][0].ToString() : "";
                    string description = res.Properties["description"].Count > 0 ? res.Properties["description"][0].ToString() : "";
                    list.Add(new ComputerResult { Name = name, Type = "Ordinateur", IP = "", Description = description });
                }
            }
            return list;
        }

        private void BtnRDP_Click(object sender, RoutedEventArgs e)
        {
            var selected = ResultsList.SelectedItem as ComputerResult;
            if (selected == null || string.IsNullOrWhiteSpace(selected.Name))
            {
                Log("Sélectionne un ordinateur dans la liste.");
                return;
            }
            try
            {
                System.Diagnostics.Process.Start("mstsc.exe", $"/v:{selected.Name}");
                Log($"Ouverture de la session RDP sur {selected.Name}");
            }
            catch (Exception ex)
            {
                Log($"Erreur RDP : {ex.Message}");
            }
        }

        private void BtnPS_Click(object sender, RoutedEventArgs e)
        {
            var selected = ResultsList.SelectedItem as ComputerResult;
            if (selected == null || string.IsNullOrWhiteSpace(selected.Name))
            {
                Log("Sélectionne un ordinateur dans la liste.");
                return;
            }
            try
            {
                System.Diagnostics.Process.Start("powershell.exe", $"-NoExit -Command Enter-PSSession -ComputerName {selected.Name}");
                Log($"Ouverture d'une session PowerShell distante sur {selected.Name}");
            }
            catch (Exception ex)
            {
                Log($"Erreur PowerShell distante : {ex.Message}");
            }
        }

        private void BtnMSRA_Click(object sender, RoutedEventArgs e)
        {
            var selected = ResultsList.SelectedItem as ComputerResult;
            if (selected == null || string.IsNullOrWhiteSpace(selected.Name))
            {
                Log("Sélectionne un ordinateur dans la liste.");
                return;
            }
            try
            {
                System.Diagnostics.Process.Start("msra.exe", $"/offerra {selected.Name}");
                Log($"Démarrage de l'assistance à distance MSRA sur {selected.Name}");
            }
            catch (Exception ex)
            {
                Log($"Erreur MSRA : {ex.Message}");
            }
        }

        private void BtnCShare_Click(object sender, RoutedEventArgs e)
        {
            var selected = ResultsList.SelectedItem as ComputerResult;
            if (selected == null || string.IsNullOrWhiteSpace(selected.Name))
            {
                Log("Sélectionne un ordinateur dans la liste.");
                return;
            }
            try
            {
                System.Diagnostics.Process.Start("explorer.exe", $"\\\\{selected.Name}\\c$");
                Log($"Ouverture du partage C$ sur {selected.Name}");
            }
            catch (Exception ex)
            {
                Log($"Erreur C$ : {ex.Message}");
            }
        }

        private void BtnVNC_Click(object sender, RoutedEventArgs e)
        {
            Log("Connexion VNC...");
            // TODO : Ajouter la logique VNC
        }

        private void Log(string message)
        {
            LogBox.AppendText(message + "\n");
            LogBox.ScrollToEnd();
        }
    }

    public class ComputerResult
    {
        public string Name { get; set; }
        public string Type { get; set; }
        public string IP { get; set; }
        public string Description { get; set; } // Ajouté
    }
}
