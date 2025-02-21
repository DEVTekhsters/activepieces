import { t } from 'i18next';

import { flagsHooks } from '@/hooks/flags-hooks';
import GTLogo from '../../assets/img/custom/GoTrust.png'

const FullLogo = () => {
  const branding = flagsHooks.useWebsiteBranding();

  return (
    <div className="h-[60px]">
      <img
        className="h-full"
        src={GTLogo}
        alt={t('logo')}
      />
    </div>
  );
};
FullLogo.displayName = 'FullLogo';
export { FullLogo };
