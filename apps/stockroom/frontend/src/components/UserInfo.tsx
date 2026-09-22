import React from 'react';
import { User } from '../types/api';
import { Card, CardContent } from '@/components/ui/card';

interface UserInfoProps {
    user: User;
}

const UserInfo: React.FC<UserInfoProps> = ({ user }) => {
    return (
        <Card>
            <CardContent className="pt-6">
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4 text-sm">
                    <div>
                        <span className="text-muted-foreground">이름</span>
                        <p className="font-medium">{user.english_name}</p>
                    </div>
                    <div>
                        <span className="text-muted-foreground">이메일</span>
                        <p className="font-medium">{user.email || '-'}</p>
                    </div>
                    <div>
                        <span className="text-muted-foreground">조직</span>
                        <p className="font-medium">{user.organization_name || '미설정'}</p>
                    </div>
                    <div>
                        <span className="text-muted-foreground">팀</span>
                        <p className="font-medium">{user.team_name}</p>
                    </div>
                </div>
            </CardContent>
        </Card>
    );
};

export default UserInfo;
