// SPDX-License-Identifier: GPL-3.0-or-later
#include <QFileInfo>
#include <QLocale>
#include <QPluginLoader>
#include <memory>
#include <stdexcept>
#include "viewpages/ViewStep.h"
#include "modulesystem/Requirement.h"
#include "utils/PluginFactory.h"

// Delegate the UI and standard checks to the unchanged upstream welcome plugin.
class Welcome : public Calamares::ViewStep
{
    Q_OBJECT
public:
    explicit Welcome(QObject* parent = nullptr)
        : ViewStep(parent), loader(UPSTREAM_WELCOME)
    {
        auto* factory = qobject_cast<CalamaresPluginFactory*>(loader.instance());
        if (!factory)
            throw std::runtime_error("Cannot load upstream Calamares welcome plugin");
        upstream.reset(factory->create<Calamares::ViewStep>());
        if (!upstream)
            throw std::runtime_error("Cannot create upstream Calamares welcome view");
        connect(upstream.get(), &ViewStep::nextStatusChanged, this, &ViewStep::nextStatusChanged);
        connect(upstream.get(), &ViewStep::ensureSize, this, &ViewStep::ensureSize);
    }

    QString prettyName() const override { return upstream->prettyName(); }
    QWidget* widget() override { return upstream->widget(); }
    bool isNextEnabled() const override { return upstream->isNextEnabled(); }
    bool isBackEnabled() const override { return upstream->isBackEnabled(); }
    bool isAtBeginning() const override { return upstream->isAtBeginning(); }
    bool isAtEnd() const override { return upstream->isAtEnd(); }
    void next() override { upstream->next(); }
    void back() override { upstream->back(); }
    void onActivate() override { upstream->onActivate(); }
    void onLeave() override { upstream->onLeave(); }
    void onCancel() override { upstream->onCancel(); }
    Calamares::JobList jobs() const override { return upstream->jobs(); }
    void setConfigurationMap(const QVariantMap& config) override
    {
        upstream->setModuleInstanceKey(moduleInstanceKey());
        upstream->setConfigurationMap(config);
    }
    Calamares::RequirementsList checkRequirements() override
    {
        auto requirements = upstream->checkRequirements();
        requirements.append({
            QStringLiteral("uefi"),
            [] { return QLocale().language() == QLocale::German
                ? QStringLiteral("Dieser Installer benötigt UEFI und einen EFI-Bootloader.")
                : QStringLiteral("This installer requires UEFI and an EFI bootloader."); },
            [] { return QLocale().language() == QLocale::German
                ? QStringLiteral("Im BIOS-Modus gestartet. Installationsmedium im UEFI-Modus neu starten. Bei VMs UEFI/OVMF wählen. BIOS-Installation wird nicht unterstützt.")
                : QStringLiteral("Started in BIOS mode. Restart the installation medium in UEFI mode. For VMs select UEFI/OVMF. BIOS installation is not supported."); },
            QFileInfo::exists(QStringLiteral("/sys/firmware/efi")),
            true
        });
        return requirements;
    }
private:
    QPluginLoader loader;
    std::unique_ptr<Calamares::ViewStep> upstream;
};

CALAMARES_PLUGIN_FACTORY_DECLARATION(WelcomeFactory)
CALAMARES_PLUGIN_FACTORY_DEFINITION(WelcomeFactory, registerPlugin<Welcome>();)
#include "Welcome.moc"
