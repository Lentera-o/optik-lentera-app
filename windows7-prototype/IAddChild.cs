using System.Windows.Controls;
using System.Windows.Documents;

namespace OptikLentera.Win7
{
    // Compatibility adapter for adding a FixedPage to PageContent.
    // Keeps the print path independent of a missing namespace import.
    internal sealed class IAddChild
    {
        private readonly PageContent pageContent;

        private IAddChild(PageContent content)
        {
            pageContent = content;
        }

        public static explicit operator IAddChild(PageContent content)
        {
            return new IAddChild(content);
        }

        public void AddChild(object child)
        {
            pageContent.Child = child as FixedPage;
        }
    }
}
